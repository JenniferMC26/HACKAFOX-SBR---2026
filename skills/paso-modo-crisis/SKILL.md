---
name: vialibretj-modo-crisis
description: >
  Implementa el Modo Crisis de VíaLibre TJ: protocolo de emergencia cuando el usuario
  queda varado mid-ruta. Busca el punto seguro accesible más cercano, calcula ruta
  alternativa, notifica contactos de emergencia con ubicación en tiempo real vía
  Firebase, y actualiza la posición cada 10 segundos. Úsalo al implementar
  POST /crisis/start, PUT /crisis/:id/update, DELETE /crisis/:id/resolve, al diseñar
  el flujo de notificación a contactos, al coordinar dos usuarios en tiempo real
  con Firebase Realtime, o cuando el usuario diga "Modo Crisis", "usuario varado",
  "protocolo de emergencia", "pedir ayuda desde la ruta", "contacto de emergencia"
  o "coordinación en tiempo real Firebase".
---

# VíaLibre TJ — Modo Crisis

El Modo Crisis existe porque la ciudad falla — no la app. Cuando el usuario queda
bloqueado a mitad de su ruta (rampa inaccesible, obstáculo inesperado, camión lleno),
el sistema activa un protocolo de emergencia: encuentra el punto seguro más cercano,
notifica a contactos de confianza con ubicación exacta, y coordina en tiempo real.

**Propuesta de valor**: "Cuando la ciudad te falla a mitad del camino, VíaLibre TJ
no te deja solo."

**Framing importante**: No es que la app falle — es que la ciudad falla, y la app
te protege igual.

---

## Tres endpoints

### 1. `POST /crisis/start` — Iniciar sesión de crisis
### 2. `PUT /crisis/:sessionId/update` — Actualizar posición (cada 10s)
### 3. `DELETE /crisis/:sessionId/resolve` — Resolver sesión

---

## Estructuras de datos en Firebase

```json
// /crisis_sessions/{sessionId}
{
  "userId": "uid_abc",
  "userProfile": "wheelchair",
  "startedAt": 1748430000000,
  "currentLat": 32.5022,
  "currentLng": -117.0080,
  "blockedNodeId": "node_rampa_destruida_av4",
  "status": "active | resolved",
  "alertedContacts": ["uid_contact_1"],
  "nearestSafePoint": {
    "name": "Farmacia Similares",
    "lat": 32.5025,
    "lng": -117.0082,
    "distanceMeters": 80,
    "type": "pharmacy"
  },
  "alternativeRoute": {
    "encodedPolyline": "...",
    "distanceMeters": 350,
    "accessibilityScore": 8.0
  },
  "lastUpdated": 1748430060000
}

// /users/{contactUid}/notifications/{notifId}
{
  "type": "crisis_alert",
  "fromUserId": "uid_abc",
  "sessionId": "crisis_xyz",
  "message": "Ángel necesita ayuda. Está varado en Calle 4ta y Av. Constitución.",
  "lat": 32.5022,
  "lng": -117.0080,
  "createdAt": 1748430000000,
  "read": false
}
```

---

## Implementación — Cloud Functions

```javascript
// functions/src/crisis/crisis.js
const admin = require('firebase-admin');
const { getAccessibleRoute } = require('../routes/routing');

// Tipos de puntos seguros ordenados por preferencia
const SAFE_POINT_TYPES = ['pharmacy', 'hospital', 'store', 'bus_stop', 'park'];

async function startCrisis({ userId, lat, lng, userProfile, blockedNodeId }) {
  const db = admin.database();
  const sessionId = `crisis_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
  
  // 1. Encontrar el punto seguro accesible más cercano
  const safePoint = await findNearestSafePoint(lat, lng, userProfile, db);
  
  // 2. Calcular ruta alternativa hacia el punto seguro
  let alternativeRoute = null;
  if (safePoint) {
    try {
      const routeResult = await getAccessibleRoute(
        { lat, lng },
        { lat: safePoint.lat, lng: safePoint.lng },
        userProfile,
        null
      );
      alternativeRoute = routeResult.route;
    } catch (err) {
      console.error('Error calculando ruta de crisis:', err);
    }
  }
  
  // 3. Crear sesión de crisis en Firebase
  const sessionData = {
    userId,
    userProfile,
    startedAt: Date.now(),
    currentLat: lat,
    currentLng: lng,
    blockedNodeId: blockedNodeId || null,
    status: 'active',
    alertedContacts: [],
    nearestSafePoint: safePoint,
    alternativeRoute,
    lastUpdated: Date.now()
  };
  
  await db.ref(`crisis_sessions/${sessionId}`).set(sessionData);
  
  // 4. Notificar contactos de emergencia del usuario
  const contactsNotified = await notifyEmergencyContacts(userId, sessionId, lat, lng, db);
  
  // 5. Actualizar lista de contactos alertados
  if (contactsNotified.length > 0) {
    await db.ref(`crisis_sessions/${sessionId}/alertedContacts`).set(contactsNotified);
  }
  
  // 6. Si hay un nodo bloqueado, reportarlo automáticamente
  if (blockedNodeId) {
    await db.ref(`accessibility_layer/${blockedNodeId}`).update({
      accessible: false,
      lastReported: new Date().toISOString(),
      reportCount: admin.database.ServerValue.increment(1)
    });
  }
  
  return {
    sessionId,
    safePoint,
    alternativeRoute,
    contactsNotified: contactsNotified.length,
    message: safePoint
      ? `Encontré "${safePoint.name}" a ${safePoint.distanceMeters}m de ti. Tus contactos fueron notificados.`
      : 'Tus contactos fueron notificados con tu ubicación. No encontré un punto seguro cercano.'
  };
}

async function findNearestSafePoint(lat, lng, userProfile, db) {
  const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
  
  // Buscar puntos seguros con Places API Nearby Search
  // Prioridad: farmacia > hospital > tienda 24h > parada cubierta
  for (const type of SAFE_POINT_TYPES) {
    const placesType = mapToPlacesType(type);
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json` +
      `?location=${lat},${lng}&radius=400&type=${placesType}&language=es&key=${GOOGLE_MAPS_API_KEY}`;
    
    try {
      const res = await fetch(url);
      const data = await res.json();
      
      if (data.status === 'OK' && data.results?.length > 0) {
        const place = data.results[0];
        const placeLat = place.geometry.location.lat;
        const placeLng = place.geometry.location.lng;
        const distanceMeters = haversineDistance(lat, lng, placeLat, placeLng);
        
        // Verificar que el punto sea accesible según nuestra capa de Firebase
        const isAccessible = await checkNodeAccessibility(placeLat, placeLng, db);
        
        if (isAccessible) {
          return {
            name: place.name,
            lat: placeLat,
            lng: placeLng,
            distanceMeters: Math.round(distanceMeters),
            type,
            placeId: place.place_id
          };
        }
      }
    } catch (err) {
      console.error(`Error buscando ${type} en Places API:`, err);
    }
  }
  
  // Fallback: buscar en Firebase el nodo accesible más cercano con score >= 7
  return findNearestAccessibleNode(lat, lng, db);
}

async function findNearestAccessibleNode(lat, lng, db) {
  const radiusDeg = 0.004; // ~400m
  
  const snapshot = await db.ref('accessibility_layer')
    .orderByChild('lat')
    .startAt(lat - radiusDeg)
    .endAt(lat + radiusDeg)
    .once('value');
  
  const nodes = Object.values(snapshot.val() || {})
    .filter(node =>
      Math.abs(node.lng - lng) < radiusDeg &&
      node.score >= 7 &&
      node.accessible === true
    )
    .map(node => ({
      ...node,
      distance: haversineDistance(lat, lng, node.lat, node.lng)
    }))
    .sort((a, b) => a.distance - b.distance);
  
  if (nodes.length === 0) return null;
  
  const nearest = nodes[0];
  return {
    name: 'Punto accesible validado',
    lat: nearest.lat,
    lng: nearest.lng,
    distanceMeters: Math.round(nearest.distance),
    type: nearest.type || 'sidewalk'
  };
}

async function checkNodeAccessibility(lat, lng, db) {
  const radiusDeg = 0.001; // ~100m
  
  const snapshot = await db.ref('accessibility_layer')
    .orderByChild('lat')
    .startAt(lat - radiusDeg)
    .endAt(lat + radiusDeg)
    .once('value');
  
  const nodes = Object.values(snapshot.val() || {})
    .filter(node => Math.abs(node.lng - lng) < radiusDeg);
  
  // Si no hay datos: asumir que es accesible (beneficio de la duda)
  if (nodes.length === 0) return true;
  
  const avgScore = nodes.reduce((sum, n) => sum + n.score, 0) / nodes.length;
  return avgScore >= 5;
}

async function notifyEmergencyContacts(userId, sessionId, lat, lng, db) {
  // Obtener contactos del usuario
  const userSnapshot = await db.ref(`users/${userId}/profile/emergencyContacts`).once('value');
  const contacts = userSnapshot.val() || [];
  
  const notifiedContacts = [];
  
  for (const contactUid of contacts) {
    const notifId = `notif_${Date.now()}_${contactUid.substr(0, 4)}`;
    
    const notification = {
      type: 'crisis_alert',
      fromUserId: userId,
      sessionId,
      message: `Tu contacto necesita ayuda. Está varado cerca de las coordenadas (${lat.toFixed(4)}, ${lng.toFixed(4)}).`,
      lat,
      lng,
      createdAt: Date.now(),
      read: false
    };
    
    await db.ref(`users/${contactUid}/notifications/${notifId}`).set(notification);
    notifiedContacts.push(contactUid);
  }
  
  return notifiedContacts;
}

async function updateCrisisPosition(sessionId, lat, lng) {
  const db = admin.database();
  
  await db.ref(`crisis_sessions/${sessionId}`).update({
    currentLat: lat,
    currentLng: lng,
    lastUpdated: Date.now()
  });
  
  // Firebase Realtime DB propaga automáticamente a todos los listeners
  // El contacto de emergencia que tenga el dashboard abierto verá la actualización
  return { updated: true, timestamp: Date.now() };
}

async function resolveCrisis(sessionId) {
  const db = admin.database();
  
  // Marcar sesión como resuelta
  await db.ref(`crisis_sessions/${sessionId}`).update({
    status: 'resolved',
    resolvedAt: Date.now()
  });
  
  // Leer contactos alertados para limpiar notificaciones activas
  const sessionSnapshot = await db.ref(`crisis_sessions/${sessionId}/alertedContacts`).once('value');
  const contacts = sessionSnapshot.val() || [];
  
  // Marcar notificaciones como leídas
  for (const contactUid of contacts) {
    const notifsSnapshot = await db.ref(`users/${contactUid}/notifications`)
      .orderByChild('sessionId')
      .equalTo(sessionId)
      .once('value');
    
    const updates = {};
    Object.keys(notifsSnapshot.val() || {}).forEach(key => {
      updates[`${key}/read`] = true;
    });
    
    if (Object.keys(updates).length > 0) {
      await db.ref(`users/${contactUid}/notifications`).update(updates);
    }
  }
  
  return { resolved: true, sessionId };
}

// Utilidades
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000; // radio de la Tierra en metros
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function mapToPlacesType(type) {
  const map = {
    pharmacy: 'pharmacy',
    hospital: 'hospital',
    store: 'convenience_store',
    bus_stop: 'transit_station',
    park: 'park'
  };
  return map[type] || type;
}

module.exports = { startCrisis, updateCrisisPosition, resolveCrisis };
```

---

## Registro en index.js

```javascript
// functions/index.js (fragmento)
const { startCrisis, updateCrisisPosition, resolveCrisis } = require('./src/crisis/crisis');

exports.crisisStart = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    const { userId, lat, lng, userProfile, blockedNodeId } = req.body;
    if (!userId || !lat || !lng) return res.status(400).json({ error: 'userId, lat y lng requeridos' });
    try {
      const result = await startCrisis({ userId, lat: parseFloat(lat), lng: parseFloat(lng), userProfile: userProfile || 'walker', blockedNodeId });
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
});

exports.crisisUpdate = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'PUT') return res.status(405).send('Method Not Allowed');
    const { sessionId } = req.params;
    const { lat, lng } = req.body;
    try {
      const result = await updateCrisisPosition(sessionId, parseFloat(lat), parseFloat(lng));
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
});

exports.crisisResolve = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'DELETE') return res.status(405).send('Method Not Allowed');
    const sessionId = req.path.split('/').pop();
    try {
      const result = await resolveCrisis(sessionId);
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
});
```

---

## HTML de prueba — dos pestañas

El Modo Crisis se prueba con **dos pestañas del navegador** simultáneamente:

### Pestaña 1 — Usuario varado

```html
<button onclick="iniciarCrisis()">🚨 Estoy varado</button>
<div id="estado-crisis"></div>
<div id="punto-seguro"></div>

<script type="module">
import { getDatabase, ref, onValue } from 'firebase-database';

const db = getDatabase(app);
let crisisSessionId = null;
let positionInterval = null;

async function iniciarCrisis() {
  const pos = await getCurrentPosition();
  
  const res = await fetch('https://us-central1-vialibretj.cloudfunctions.net/crisisStart', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: 'test_user_wheelchair',
      lat: pos.lat,
      lng: pos.lng,
      userProfile: 'wheelchair'
    })
  });
  
  const data = await res.json();
  crisisSessionId = data.sessionId;
  
  document.getElementById('estado-crisis').textContent = data.message;
  document.getElementById('punto-seguro').textContent = 
    data.safePoint ? `Ir a: ${data.safePoint.name} (${data.safePoint.distanceMeters}m)` : 'Sin punto seguro cercano';
  
  // Actualizar posición cada 10 segundos
  positionInterval = setInterval(() => actualizarPosicion(crisisSessionId), 10000);
}

async function actualizarPosicion(sessionId) {
  const pos = await getCurrentPosition();
  await fetch(`https://us-central1-vialibretj.cloudfunctions.net/crisisUpdate`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sessionId, lat: pos.lat, lng: pos.lng })
  });
}

async function resolverCrisis() {
  clearInterval(positionInterval);
  await fetch(`https://us-central1-vialibretj.cloudfunctions.net/crisisResolve/${crisisSessionId}`, {
    method: 'DELETE'
  });
}
</script>
```

### Pestaña 2 — Contacto de emergencia

```html
<!-- El contacto ve la posición en tiempo real sin recargar la página -->
<div id="mapa-crisis"></div>
<div id="info-crisis">Esperando alerta...</div>

<script type="module">
import { getDatabase, ref, onValue } from 'firebase-database';

const db = getDatabase(app);
const CONTACT_UID = 'test_user_contact';

// Escuchar notificaciones del contacto
onValue(ref(db, `users/${CONTACT_UID}/notifications`), snapshot => {
  const notifs = snapshot.val() || {};
  const crisisAlert = Object.values(notifs).find(n => n.type === 'crisis_alert' && !n.read);
  
  if (crisisAlert) {
    document.getElementById('info-crisis').textContent = crisisAlert.message;
    
    // Escuchar actualizaciones de posición en tiempo real
    onValue(ref(db, `crisis_sessions/${crisisAlert.sessionId}/currentLat`), latSnap => {
      onValue(ref(db, `crisis_sessions/${crisisAlert.sessionId}/currentLng`), lngSnap => {
        const lat = latSnap.val();
        const lng = lngSnap.val();
        if (lat && lng) actualizarMarkerEnMapa(lat, lng);
      });
    });
  }
});
</script>
```

---

## Notas de implementación

- **Firebase como canal de coordinación**: `onValue()` escucha cambios en tiempo real. No se necesita polling — Firebase notifica automáticamente a todos los listeners conectados cuando se hace `update()`.
- **Actualización de posición**: el intervalo de 10 segundos es un balance entre precisión y costo de operaciones en Firebase. En la demo, puede reducirse a 5s.
- **Fallback de punto seguro**: si Places API no responde, buscar en `/accessibility_layer` el nodo con `score >= 7` más cercano. Siempre devolver algo.
- **Limpiar sesiones antiguas**: las sesiones de crisis con más de 2 horas de antigüedad y status `active` probablemente sean sesiones abandonadas. Considerar una Cloud Function programada que las resuelva automáticamente.
- **Resolución del crisis**: cuando el usuario llega a su destino o presiona "Estoy bien", llamar a `DELETE /crisis/:id` para limpiar notificaciones y marcar como resuelto.
