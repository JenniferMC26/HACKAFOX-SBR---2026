---
name: vialibretj-routing-engine
description: >
  Implementa el motor de ruteo accesible para VíaLibre TJ — la pieza central del backend
  que diferencia rutas según perfil de usuario (silla de ruedas vs adulto mayor) y filtra
  segmentos por la capa de accesibilidad de Firebase. Úsalo al implementar o modificar
  POST /routing/accessible, al ajustar los umbrales de accesibilidad por perfil, al
  integrar la capa de Ruta Viva al resultado, o cuando el usuario diga "implementar ruteo",
  "modificar la ruta", "calcular camino accesible" o "endpoint de navegación". Es el
  núcleo compartido del que dependen Ruta Viva y Modo Crisis.
---

# VíaLibre TJ — Motor de Ruteo Accesible

El motor de ruteo es la columna vertebral del backend. Toma un origen y destino,
consulta la capa de accesibilidad en Firebase, y devuelve la ruta más segura
diferenciada por perfil de usuario.

## Responsabilidades

1. Llamar a Google Maps Routes API con `travelMode: WALK`
2. Leer nodos de `/accessibility_layer` en Firebase para cada segmento de la ruta
3. Calcular un `routeAccessibilityScore` ponderado por segmento
4. Generar advertencias en puntos con score bajo
5. Intentar ruta alternativa si hay segmentos críticos según el perfil
6. Inyectar el ajuste de Ruta Viva si se proporciona `arrivalTime`

---

## Endpoint

```
POST /routing/accessible
Content-Type: application/json
```

### Request

```json
{
  "origin": { "lat": 32.5000, "lng": -117.0100 },
  "destination": { "lat": 32.5050, "lng": -117.0020 },
  "userProfile": "wheelchair | elderly | walker",
  "arrivalTime": "2025-05-28T14:30:00-07:00"  // opcional — activa Ruta Viva
}
```

### Response

```json
{
  "route": {
    "encodedPolyline": "...",
    "distanceMeters": 850,
    "durationSeconds": 720,
    "accessibilityScore": 7.4,
    "warnings": [
      {
        "type": "broken_ramp | blocked_sidewalk | uneven_surface | missing_ramp",
        "lat": 32.5022,
        "lng": -117.008,
        "severity": 5,
        "message": "Rampa dañada reportada hace 2 días"
      }
    ]
  },
  "rutaVivaAdjustment": {
    "predictedScore": 6.1,
    "reason": "Mercado ambulante los miércoles 10am-2pm reduce accesibilidad",
    "applied": true
  },
  "alternativeRoute": null  // se llena si la ruta principal tiene score < umbral
}
```

---

## Implementación — Cloud Function

```javascript
// functions/src/routes/routing.js
const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');
const { getRutaVivaScore } = require('../ruta-viva/prediction');

const ROUTES_API_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

// Umbrales por perfil — determinan qué se considera "inaceptable"
const PROFILE_THRESHOLDS = {
  wheelchair: {
    minScore: 5,           // score mínimo por segmento aceptable
    avoidBarrierTypes: ['broken_ramp', 'missing_ramp', 'no_curb_cut'],
    maxSlopePct: 6
  },
  elderly: {
    minScore: 4,
    avoidBarrierTypes: ['missing_ramp'],
    maxSlopePct: 10
  },
  walker: {
    minScore: 2,
    avoidBarrierTypes: [],
    maxSlopePct: 20
  }
};

async function getAccessibleRoute(origin, destination, userProfile, arrivalTime) {
  const threshold = PROFILE_THRESHOLDS[userProfile] || PROFILE_THRESHOLDS.walker;
  
  // 1. Obtener ruta base de Maps Routes API
  const baseRoute = await fetchMapsRoute(origin, destination);
  
  // 2. Consultar nodos de accesibilidad relevantes en Firebase
  const accessibilityNodes = await getNodesAlongRoute(baseRoute.encodedPolyline);
  
  // 3. Calcular score y warnings
  const { score, warnings } = scoreRoute(accessibilityNodes, threshold);
  
  // 4. Ajuste de Ruta Viva (si arrivalTime fue proporcionado)
  let rutaVivaAdjustment = null;
  if (arrivalTime) {
    rutaVivaAdjustment = await getRutaVivaScore(
      origin.lat, origin.lng,
      destination.lat, destination.lng,
      arrivalTime
    );
  }
  
  // 5. Si score es crítico, intentar ruta alternativa
  let alternativeRoute = null;
  const criticalWarnings = warnings.filter(w => 
    threshold.avoidBarrierTypes.includes(w.type) || w.severity >= 7
  );
  
  if (criticalWarnings.length > 0) {
    alternativeRoute = await findAlternativeRoute(
      origin, destination, criticalWarnings, userProfile
    );
  }
  
  return {
    route: {
      encodedPolyline: baseRoute.encodedPolyline,
      distanceMeters: baseRoute.distanceMeters,
      durationSeconds: baseRoute.durationSeconds,
      accessibilityScore: score,
      warnings
    },
    rutaVivaAdjustment,
    alternativeRoute
  };
}

async function fetchMapsRoute(origin, destination) {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/maps-platform.routespreferred']
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  
  const response = await fetch(ROUTES_API_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token.token}`,
      'Content-Type': 'application/json',
      'X-Goog-FieldMask': 'routes.encodedPolyline,routes.distanceMeters,routes.duration'
    },
    body: JSON.stringify({
      origin: { location: { latLng: origin } },
      destination: { location: { latLng: destination } },
      travelMode: 'WALK',
      computeAlternativeRoutes: false
    })
  });
  
  const data = await response.json();
  const route = data.routes?.[0];
  if (!route) throw new Error('Maps API no devolvió ruta');
  
  return {
    encodedPolyline: route.encodedPolyline.encodedPolyline,
    distanceMeters: route.distanceMeters,
    durationSeconds: parseInt(route.duration)
  };
}

async function getNodesAlongRoute(encodedPolyline) {
  // Decodificar polyline y obtener bounding box
  const points = decodePolyline(encodedPolyline);
  const bounds = getBoundingBox(points, 0.0005); // ~50m de radio
  
  const db = admin.database();
  const snapshot = await db.ref('accessibility_layer')
    .orderByChild('lat')
    .startAt(bounds.minLat)
    .endAt(bounds.maxLat)
    .once('value');
  
  const allNodes = snapshot.val() || {};
  
  // Filtrar solo nodos dentro del bounding box completo
  return Object.values(allNodes).filter(node =>
    node.lng >= bounds.minLng && node.lng <= bounds.maxLng
  );
}

function scoreRoute(nodes, threshold) {
  if (nodes.length === 0) {
    // Sin datos: score neutro con advertencia
    return {
      score: 5.0,
      warnings: [{ type: 'unvalidated', message: 'Tramo sin validación reciente', severity: 0 }]
    };
  }
  
  const warnings = [];
  let totalScore = 0;
  
  nodes.forEach(node => {
    totalScore += node.score;
    
    if (node.score < threshold.minScore || 
        (node.barrierType && threshold.avoidBarrierTypes.includes(node.barrierType))) {
      warnings.push({
        type: node.barrierType || 'low_score',
        lat: node.lat,
        lng: node.lng,
        severity: 10 - node.score,
        message: `Obstáculo reportado: ${node.barrierType || 'accesibilidad reducida'}`
      });
    }
  });
  
  return {
    score: parseFloat((totalScore / nodes.length).toFixed(1)),
    warnings
  };
}

async function findAlternativeRoute(origin, destination, criticalPoints, userProfile) {
  // Crear waypoints que eviten los puntos críticos
  // Estrategia simple: añadir un desvío de 100m perpendicular al punto crítico
  // En producción, esto debería usar algoritmos más sofisticados
  
  // Por ahora devolvemos null si no podemos calcular alternativa
  // TODO: implementar desvío real con waypoints
  return null;
}

// Helpers
function decodePolyline(encoded) {
  // Implementación estándar del algoritmo de decodificación de polyline de Google
  const points = [];
  let index = 0, lat = 0, lng = 0;
  
  while (index < encoded.length) {
    let b, shift = 0, result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) ? ~(result >> 1) : result >> 1;
    
    shift = 0; result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) ? ~(result >> 1) : result >> 1;
    
    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return points;
}

function getBoundingBox(points, margin) {
  const lats = points.map(p => p.lat);
  const lngs = points.map(p => p.lng);
  return {
    minLat: Math.min(...lats) - margin,
    maxLat: Math.max(...lats) + margin,
    minLng: Math.min(...lngs) - margin,
    maxLng: Math.max(...lngs) + margin
  };
}

module.exports = { getAccessibleRoute };
```

---

## Registro en index.js

```javascript
// functions/index.js (fragmento)
const functions = require('firebase-functions');
const cors = require('cors')({ origin: true });
const { getAccessibleRoute } = require('./src/routes/routing');

exports.routingAccessible = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    
    const { origin, destination, userProfile, arrivalTime } = req.body;
    
    if (!origin || !destination || !userProfile) {
      return res.status(400).json({ error: 'origin, destination y userProfile son requeridos' });
    }
    
    try {
      const result = await getAccessibleRoute(origin, destination, userProfile, arrivalTime);
      res.json(result);
    } catch (err) {
      console.error('Error en routing:', err);
      res.status(500).json({ error: err.message });
    }
  });
});
```

---

## HTML de prueba — fragmento relevante

```html
<!-- test-routing.html -->
<script>
async function calcularRuta() {
  const origin = {
    lat: parseFloat(document.getElementById('lat-origen').value),
    lng: parseFloat(document.getElementById('lng-origen').value)
  };
  const destination = {
    lat: parseFloat(document.getElementById('lat-destino').value),
    lng: parseFloat(document.getElementById('lng-destino').value)
  };
  const userProfile = document.getElementById('perfil').value;
  
  const res = await fetch('https://us-central1-vialibretj.cloudfunctions.net/routingAccessible', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ origin, destination, userProfile })
  });
  
  const data = await res.json();
  
  // Mostrar score y warnings
  document.getElementById('score').textContent = data.route.accessibilityScore;
  
  // Dibujar ruta en mapa
  const decodedPath = google.maps.geometry.encoding.decodePath(data.route.encodedPolyline);
  new google.maps.Polyline({ path: decodedPath, map: map, strokeColor: '#1976D2' });
  
  // Agregar markers de advertencia
  data.route.warnings.forEach(w => {
    new google.maps.Marker({
      position: { lat: w.lat, lng: w.lng },
      map,
      icon: { url: 'http://maps.google.com/mapfiles/ms/icons/red-dot.png' }
    });
  });
}
</script>
```

---

## Notas de implementación

- **Perfiles diferenciados**: `wheelchair` tiene umbrales más estrictos que `elderly` que a su vez más que `walker`. Los `avoidBarrierTypes` determinan qué barreras son absolutamente inaceptables para ese perfil.
- **Score neutro (5.0)**: si no hay nodos de Firebase cerca de la ruta, devolver 5.0 con advertencia `unvalidated` en lugar de fallar.
- **CORS**: siempre aplicar el middleware `cors` antes de cualquier lógica. El HTML de prueba corre en `localhost` y necesita CORS habilitado.
- **Decodificación de polyline**: implementar el algoritmo estándar de Google o usar la librería `@googlemaps/polyline-codec`.
