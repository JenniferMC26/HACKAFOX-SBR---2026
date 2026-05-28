---
name: vialibretj-ruta-viva
description: >
  Implementa Ruta Viva para VíaLibre TJ: ruteo predictivo que cruza hora del día,
  día de semana y patrones históricos de BigQuery para predecir si una ruta estará
  accesible cuando el usuario llegue — no solo si está accesible ahora. Úsalo al
  implementar GET /ruta-viva/score, al ajustar las queries de BigQuery de predicción
  temporal, al integrar el score predictivo al motor de ruteo, o cuando el usuario
  diga "Ruta Viva", "predecir accesibilidad", "accesibilidad a cierta hora",
  "score temporal", "tianguis los miércoles" o "ruteo predictivo". Depende de que
  vialibretj-seed-data haya corrido primero para tener datos en temporal_patterns.
---

# VíaLibre TJ — Ruta Viva

Ruta Viva es el diferenciador competitivo clave. En lugar de decirte cómo está
la ruta **ahora**, predice cómo estará **cuando llegues**. Cruza patrones históricos
de reportes con hora y día de la semana para generar un score predictivo.

**Propuesta de valor**: "No te dice cómo está la ruta ahora — te dice cómo estará cuando llegues."

---

## Endpoint

```
GET /ruta-viva/score?lat=32.5027&lng=-117.0037&radius_meters=100&arrival_iso8601=2025-05-28T14:30:00-07:00
```

### Response

```json
{
  "predictedScore": 6.1,
  "currentScore": 8.2,
  "delta": -2.1,
  "reason": "Mercado ambulante los miércoles 10am-2pm reduce accesibilidad en esta zona",
  "eventFlag": "market_day",
  "confidence": "high | medium | low",
  "dataPoints": 15,
  "applied": true
}
```

- `predictedScore`: score ajustado por contexto temporal (0-10)
- `currentScore`: score actual del nodo en Firebase sin ajuste
- `delta`: diferencia (negativo = la ruta empeorará cuando llegues)
- `confidence`: "low" si hay menos de 3 puntos de datos históricos

---

## Implementación — Cloud Function

```javascript
// functions/src/ruta-viva/prediction.js
const { BigQuery } = require('@google-cloud/bigquery');
const admin = require('firebase-admin');

const bq = new BigQuery({ projectId: 'vialibretj' });

// Cache en memoria para evitar latencia de BQ en cada consulta
// TTL de 30 minutos por (lat_rounded, lng_rounded, hour, dow)
const predictionCache = new Map();
const CACHE_TTL_MS = 30 * 60 * 1000;

async function getRutaVivaScore(originLat, originLng, destLat, destLng, arrivalTimeISO) {
  const arrivalDate = new Date(arrivalTimeISO);
  const hourOfDay = arrivalDate.getHours();
  const dayOfWeek = arrivalDate.getDay(); // 0=domingo en JS, ajustar a 0=lunes

  // Normalizar day_of_week: JS usa 0=domingo, nuestra BD usa 0=lunes
  const dow = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  
  // Calcular punto medio de la ruta como referencia
  const midLat = (originLat + destLat) / 2;
  const midLng = (originLng + destLng) / 2;
  
  // Clave de cache
  const cacheKey = `${Math.round(midLat * 1000)}_${Math.round(midLng * 1000)}_${hourOfDay}_${dow}`;
  
  // Revisar cache
  const cached = predictionCache.get(cacheKey);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return cached.data;
  }
  
  // Consultar BigQuery
  const bqResult = await queryTemporalPatterns(midLat, midLng, hourOfDay, dow);
  
  // Si no hay datos suficientes, retornar fallback gracioso
  if (bqResult.dataPoints < 3) {
    const fallback = {
      predictedScore: null,
      currentScore: null,
      delta: 0,
      reason: 'Sin suficientes datos históricos para esta zona y horario',
      eventFlag: 'none',
      confidence: 'low',
      dataPoints: bqResult.dataPoints,
      applied: false
    };
    predictionCache.set(cacheKey, { data: fallback, timestamp: Date.now() });
    return fallback;
  }
  
  // Combinar score histórico con reportes recientes de Firebase (últimas 2 horas)
  const recentFirebaseScore = await getRecentFirebaseScore(midLat, midLng);
  
  // Ponderar: 70% histórico BQ + 30% Firebase reciente
  const blendedScore = recentFirebaseScore !== null
    ? bqResult.avgScore * 0.7 + recentFirebaseScore * 0.3
    : bqResult.avgScore;
  
  const result = {
    predictedScore: parseFloat(blendedScore.toFixed(1)),
    currentScore: recentFirebaseScore,
    delta: recentFirebaseScore !== null
      ? parseFloat((blendedScore - recentFirebaseScore).toFixed(1))
      : 0,
    reason: generateReason(bqResult.eventFlag, hourOfDay, dow),
    eventFlag: bqResult.eventFlag,
    confidence: bqResult.dataPoints >= 10 ? 'high' : 'medium',
    dataPoints: bqResult.dataPoints,
    applied: true
  };
  
  predictionCache.set(cacheKey, { data: result, timestamp: Date.now() });
  return result;
}

async function queryTemporalPatterns(lat, lng, hourOfDay, dow) {
  // Radio de búsqueda: ~200 metros (aproximado con grados)
  const radiusDeg = 0.002;
  
  const query = `
    SELECT
      AVG(accessibility_score) AS avg_score,
      SUM(report_count) AS total_reports,
      COUNT(*) AS data_points,
      -- El event_flag más frecuente en este horario
      APPROX_TOP_COUNT(event_flag, 1)[OFFSET(0)].value AS dominant_event
    FROM \`vialibretj.temporal_patterns\`
    WHERE
      lat BETWEEN @min_lat AND @max_lat
      AND lng BETWEEN @min_lng AND @max_lng
      AND hour_of_day = @hour
      AND day_of_week = @dow
  `;
  
  const options = {
    query,
    params: {
      min_lat: lat - radiusDeg,
      max_lat: lat + radiusDeg,
      min_lng: lng - radiusDeg,
      max_lng: lng + radiusDeg,
      hour: hourOfDay,
      dow
    }
  };
  
  try {
    const [rows] = await bq.query(options);
    const row = rows[0];
    
    return {
      avgScore: parseFloat((row.avg_score || 0.7) * 10), // convertir 0-1 a 0-10
      dataPoints: parseInt(row.data_points || 0),
      eventFlag: row.dominant_event || 'none'
    };
  } catch (err) {
    console.error('Error consultando BigQuery para Ruta Viva:', err);
    return { avgScore: 7.0, dataPoints: 0, eventFlag: 'none' };
  }
}

async function getRecentFirebaseScore(lat, lng) {
  const db = admin.database();
  const radiusDeg = 0.0005;
  
  const snapshot = await db.ref('accessibility_layer')
    .orderByChild('lat')
    .startAt(lat - radiusDeg)
    .endAt(lat + radiusDeg)
    .once('value');
  
  const nodes = Object.values(snapshot.val() || {})
    .filter(node => Math.abs(node.lng - lng) < radiusDeg);
  
  if (nodes.length === 0) return null;
  
  const avgScore = nodes.reduce((sum, n) => sum + n.score, 0) / nodes.length;
  return parseFloat(avgScore.toFixed(1));
}

function generateReason(eventFlag, hour, dow) {
  const days = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  
  const reasons = {
    market_day: `Mercado ambulante los ${days[dow]} de ${hour}:00 a ${hour + 2}:00 reduce accesibilidad en esta zona`,
    church: `Misa dominical de ${hour}:00 genera concentración de personas cerca de la iglesia`,
    rush_hour: `Hora pico de transporte público — paradas con mayor tráfico y menor espacio`,
    school_hours: `Horario escolar — banquetas y cruces con mayor concentración de personas`,
    none: 'Sin eventos especiales que afecten la accesibilidad en este horario'
  };
  
  return reasons[eventFlag] || reasons.none;
}

module.exports = { getRutaVivaScore };
```

---

## Integración con el motor de ruteo

En `routing.js`, agregar la llamada a Ruta Viva cuando `arrivalTime` está presente:

```javascript
// En getAccessibleRoute() — ya incluido en vialibretj-routing-engine
if (arrivalTime) {
  rutaVivaAdjustment = await getRutaVivaScore(
    origin.lat, origin.lng,
    destination.lat, destination.lng,
    arrivalTime
  );
  
  // Si el score predicho es significativamente peor, avisar al usuario
  if (rutaVivaAdjustment.delta < -2 && rutaVivaAdjustment.applied) {
    route.warnings.unshift({
      type: 'temporal_warning',
      message: rutaVivaAdjustment.reason,
      predictedScore: rutaVivaAdjustment.predictedScore
    });
  }
}
```

---

## Registro en index.js

```javascript
// functions/index.js (fragmento)
const { getRutaVivaScore } = require('./src/ruta-viva/prediction');

exports.rutaVivaScore = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const { lat, lng, radius_meters, arrival_iso8601 } = req.query;
    
    if (!lat || !lng || !arrival_iso8601) {
      return res.status(400).json({ error: 'lat, lng y arrival_iso8601 son requeridos' });
    }
    
    try {
      const score = await getRutaVivaScore(
        parseFloat(lat), parseFloat(lng),
        parseFloat(lat), parseFloat(lng), // mismo punto para score puntual
        arrival_iso8601
      );
      res.json(score);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
});
```

---

## HTML de prueba — fragmento

```html
<!-- Selector de hora de llegada para probar Ruta Viva -->
<input type="datetime-local" id="arrival-time">
<button onclick="probarRutaViva()">Ver predicción</button>
<div id="prediccion"></div>

<script>
async function probarRutaViva() {
  const lat = 32.5305;  // Mercado Hidalgo
  const lng = -117.0349;
  const arrival = document.getElementById('arrival-time').value;
  
  // Convertir a ISO 8601 con timezone de Tijuana (UTC-7)
  const arrivalISO = new Date(arrival).toISOString();
  
  const res = await fetch(
    `https://us-central1-vialibretj.cloudfunctions.net/rutaVivaScore` +
    `?lat=${lat}&lng=${lng}&arrival_iso8601=${encodeURIComponent(arrivalISO)}`
  );
  
  const data = await res.json();
  
  document.getElementById('prediccion').innerHTML = `
    <p>Score actual: <b>${data.currentScore}</b></p>
    <p>Score predicho para tu llegada: <b>${data.predictedScore}</b></p>
    <p>Motivo: ${data.reason}</p>
    <p>Confianza: ${data.confidence} (${data.dataPoints} registros históricos)</p>
  `;
}
</script>
```

---

## Escenarios de prueba recomendados

Para verificar que Ruta Viva funciona con el seed data:

1. **Miércoles 11am en Mercado Hidalgo (32.5305, -117.0349)** → debe devolver score bajo (~0.2), eventFlag: "market_day"
2. **Domingo 10am cerca de Catedral (32.5307, -117.0349)** → score bajo (~0.3), eventFlag: "church"
3. **Martes 3pm en Av. Revolución (32.5320, -117.0372)** → score alto (~0.8), eventFlag: "none"
4. **Cualquier día 3am** → score alto en todos los puntos

## Notas de implementación

- **Latencia de BigQuery**: las queries tardan 1-3 segundos. El cache de 30 minutos en memoria es esencial para no penalizar al usuario.
- **Fallback gracioso**: si BQ no tiene datos (`dataPoints < 3`), devolver `applied: false` en lugar de inventar un score. El motor de ruteo debe manejar este caso mostrando el score actual de Firebase.
- **Timezone**: Tijuana está en UTC-7 (UTC-8 en invierno). El `arrivalTime` debe venir en ISO 8601 con offset del cliente. Siempre parsear con `new Date(arrivalTimeISO)` que respeta el offset.
- **Conversión de score**: BigQuery guarda `accessibility_score` como `0.0-1.0`. Multiplicar por 10 para obtener la escala `0-10` que usa el resto del sistema.
