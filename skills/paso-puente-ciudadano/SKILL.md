---
name: vialibretj-puente-ciudadano
description: >
  Implementa el sistema de reportes ciudadanos de VíaLibre TJ: foto → Gemini Vision
  analiza la barrera → Firebase actualiza el mapa en tiempo real → BigQuery registra
  el historial → si severity >= 7 genera ticket formal para el municipio. Úsalo al
  implementar POST /reports/submit, al ajustar el prompt de Gemini Vision, al diseñar
  el esquema de tickets cívicos, o cuando el usuario diga "reporte ciudadano",
  "subir foto de obstáculo", "Gemini analiza imagen", "generar ticket", "Puente Ciudadano"
  o "notificar al municipio". También alimenta la capa de accesibilidad que usa el motor
  de ruteo — es la feature que mantiene el mapa vivo.
---

# VíaLibre TJ — Puente Ciudadano

El Puente Ciudadano es la feature que mantiene el mapa vivo. Un usuario ve un obstáculo,
toma una foto, y en segundos: Gemini lo analiza, Firebase actualiza el mapa de todos
los demás usuarios, y si es severo, se genera un ticket formal para el municipio.

## Flujo completo

```
Usuario toma foto
    ↓
HTML sube foto a Firebase Storage (SDK cliente)
    ↓
HTML envía photoUrl + lat + lng + userId a POST /reports/submit
    ↓
Cloud Function llama a Gemini Vision API
    ↓
Gemini devuelve análisis estructurado (barrierType, severity, etc.)
    ↓
Firebase /reports/{reportId} ← nuevo reporte
Firebase /accessibility_layer ← nodo actualizado
BigQuery accessibility_reports ← fila histórica
    ↓ (si severity >= 7)
BigQuery civic_tickets ← ticket TJ-YYYY-NNNN
    ↓
Respuesta al cliente con reportId + ticketId (si aplica)
```

---

## Endpoint

```
POST /reports/submit
Content-Type: application/json
```

### Request

```json
{
  "photoUrl": "gs://vialibretj.appspot.com/reports/foto123.jpg",
  "lat": 32.5022,
  "lng": -117.0080,
  "userId": "uid_abc"
}
```

> **Nota**: el cliente NO envía la imagen en base64 al endpoint — sube primero a
> Firebase Storage y envía la URL resultante. Esto evita límites de tamaño en Cloud Functions.

### Response

```json
{
  "reportId": "rpt_abc123",
  "ticketId": "TJ-2025-0042",
  "analysis": {
    "barrierType": "broken_ramp",
    "severity": 7,
    "passable": false,
    "affectedProfiles": ["wheelchair"],
    "description": "Rampa con grieta profunda en la base",
    "confidence": 0.92
  },
  "mapUpdated": true,
  "requiresHumanReview": false
}
```

---

## Prompt de Gemini Vision

Este prompt es la pieza más crítica del sistema. Debe devolver JSON estricto.

```javascript
// functions/src/reports/geminiVision.js
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const VISION_PROMPT = `
Eres un analizador experto de accesibilidad urbana para la ciudad de Tijuana, México.
Analiza la imagen proporcionada e identifica barreras arquitectónicas que afecten
a personas con discapacidad motriz, usuarios de silla de ruedas, adultos mayores o
personas con andadera/muletas.

Responde ÚNICAMENTE con JSON válido, sin texto adicional antes ni después:

{
  "barrierType": "<uno de: broken_ramp | missing_ramp | blocked_sidewalk | uneven_surface | no_curb_cut | construction | parked_vehicle | none>",
  "severity": <número entero del 1 al 10, donde 10 = completamente imposible de pasar>,
  "passable": <true si una silla de ruedas puede pasar con dificultad, false si es imposible>,
  "affectedProfiles": <array con los perfiles afectados: "wheelchair" | "elderly" | "walker" | "stroller">,
  "description": "<descripción en español de máximo 80 caracteres>",
  "confidence": <número decimal de 0.0 a 1.0 indicando tu certeza en el análisis>,
  "temporaryObstacle": <true si parece un obstáculo temporal como un coche mal estacionado, false si es permanente como rampa dañada>
}

Si la imagen no muestra una calle, banqueta o espacio público, responde con:
{ "barrierType": "none", "severity": 0, "passable": true, "affectedProfiles": [], "description": "No se detectó barrera", "confidence": 0.0, "temporaryObstacle": false }
`;

async function analyzeBarrierPhoto(photoUrl) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
  
  // Descargar imagen desde Firebase Storage para enviarla a Gemini
  const imageData = await fetchImageAsBase64(photoUrl);
  
  let rawText;
  try {
    const result = await model.generateContent([
      VISION_PROMPT,
      { inlineData: { data: imageData.base64, mimeType: imageData.mimeType } }
    ]);
    rawText = result.response.text().trim();
  } catch (err) {
    console.error('Error llamando a Gemini Vision:', err);
    return getFallbackAnalysis();
  }
  
  // Parsear JSON — Gemini a veces incluye markdown ```json ... ```
  try {
    const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const analysis = JSON.parse(cleaned);
    
    // Validar campos requeridos
    if (!analysis.barrierType || analysis.severity === undefined) {
      return getFallbackAnalysis();
    }
    
    return analysis;
  } catch (err) {
    console.error('Error parseando respuesta de Gemini:', rawText);
    return getFallbackAnalysis();
  }
}

function getFallbackAnalysis() {
  return {
    barrierType: 'unknown',
    severity: 5,
    passable: null,
    affectedProfiles: [],
    description: 'Análisis no disponible — revisión manual requerida',
    confidence: 0,
    temporaryObstacle: false,
    requiresHumanReview: true
  };
}

async function fetchImageAsBase64(gsUrl) {
  // Convertir gs:// URL a URL de descarga pública temporal
  const admin = require('firebase-admin');
  const bucket = admin.storage().bucket();
  
  // gsUrl formato: gs://vialibretj.appspot.com/reports/foto123.jpg
  const filePath = gsUrl.replace(`gs://${bucket.name}/`, '');
  const file = bucket.file(filePath);
  
  const [buffer] = await file.download();
  return {
    base64: buffer.toString('base64'),
    mimeType: 'image/jpeg'  // asumir JPEG; mejorar con detección real de mime
  };
}

module.exports = { analyzeBarrierPhoto };
```

---

## Cloud Function completa

```javascript
// functions/src/reports/report.js
const admin = require('firebase-admin');
const { analyzeBarrierPhoto } = require('./geminiVision');
const { BigQuery } = require('@google-cloud/bigquery');

const bq = new BigQuery({ projectId: 'vialibretj' });

async function submitReport({ photoUrl, lat, lng, userId }) {
  const db = admin.database();
  const reportId = `rpt_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
  
  // 1. Analizar foto con Gemini Vision
  const analysis = await analyzeBarrierPhoto(photoUrl);
  
  // 2. Guardar reporte en Firebase
  const reportData = {
    userId,
    lat,
    lng,
    photoUrl,
    geminiAnalysis: analysis,
    status: 'pending',
    createdAt: Date.now(),
    requiresHumanReview: analysis.confidence < 0.6 || analysis.requiresHumanReview || false
  };
  
  await db.ref(`reports/${reportId}`).set(reportData);
  
  // 3. Actualizar /accessibility_layer
  const nodeId = await updateAccessibilityLayer(lat, lng, analysis, db);
  
  // 4. Escribir en BigQuery (no bloquear la respuesta — fire and forget)
  writeToAnalytics(reportId, lat, lng, analysis).catch(console.error);
  
  // 5. Generar ticket cívico si severity >= 7
  let ticketId = null;
  if (analysis.severity >= 7 && analysis.barrierType !== 'unknown') {
    ticketId = await generateCivicTicket(reportId, lat, lng, analysis, photoUrl);
  }
  
  return {
    reportId,
    ticketId,
    analysis,
    mapUpdated: !!nodeId,
    requiresHumanReview: reportData.requiresHumanReview
  };
}

async function updateAccessibilityLayer(lat, lng, analysis, db) {
  // Buscar nodo existente más cercano (dentro de ~30m)
  const snapshot = await db.ref('accessibility_layer')
    .orderByChild('lat')
    .startAt(lat - 0.0003)
    .endAt(lat + 0.0003)
    .once('value');
  
  const nodes = snapshot.val() || {};
  let nearestNodeId = null;
  let nearestDist = Infinity;
  
  Object.entries(nodes).forEach(([id, node]) => {
    const dist = Math.abs(node.lng - lng);
    if (dist < 0.0003 && dist < nearestDist) {
      nearestDist = dist;
      nearestNodeId = id;
    }
  });
  
  const nodeData = {
    lat,
    lng,
    type: barrierTypeToNodeType(analysis.barrierType),
    accessible: analysis.barrierType === 'none' || analysis.severity < 4,
    score: Math.max(1, 10 - analysis.severity),
    lastReported: new Date().toISOString(),
    barrierType: analysis.barrierType === 'none' ? null : analysis.barrierType
  };
  
  if (nearestNodeId) {
    // Actualizar nodo existente
    await db.ref(`accessibility_layer/${nearestNodeId}`).update({
      ...nodeData,
      reportCount: (nodes[nearestNodeId].reportCount || 0) + 1
    });
    return nearestNodeId;
  } else {
    // Crear nuevo nodo
    const newNodeId = `node_report_${Date.now()}`;
    await db.ref(`accessibility_layer/${newNodeId}`).set({ ...nodeData, reportCount: 1 });
    return newNodeId;
  }
}

async function writeToAnalytics(reportId, lat, lng, analysis) {
  const now = new Date();
  const row = {
    report_id: reportId,
    user_id: 'anonymous',
    lat,
    lng,
    barrier_type: analysis.barrierType,
    severity: analysis.severity,
    hour_of_day: now.getHours(),
    day_of_week: now.getDay(),
    weather_condition: 'unknown',
    reported_at: now.toISOString(),
    resolved_at: null
  };
  
  await bq.dataset('vialibretj').table('accessibility_reports').insert([row]);
}

async function generateCivicTicket(reportId, lat, lng, analysis, photoUrl) {
  // Generar ID correlativo TJ-YYYY-NNNN
  const year = new Date().getFullYear();
  const count = await getTicketCount();
  const ticketId = `TJ-${year}-${String(count + 1).padStart(4, '0')}`;
  
  const ticket = {
    ticket_id: ticketId,
    report_id: reportId,
    lat,
    lng,
    barrier_type: analysis.barrierType,
    severity: analysis.severity,
    photo_url: photoUrl,
    gemini_description: analysis.description,
    affected_users_estimate: estimateAffectedUsers(analysis),
    created_at: new Date().toISOString(),
    assigned_to: 'municipio_tijuana',
    status: 'open'
  };
  
  await bq.dataset('vialibretj').table('civic_tickets').insert([ticket]);
  return ticketId;
}

async function getTicketCount() {
  const [rows] = await bq.query(`
    SELECT COUNT(*) as count 
    FROM \`vialibretj.civic_tickets\`
    WHERE EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM CURRENT_TIMESTAMP())
  `);
  return rows[0]?.count || 0;
}

function estimateAffectedUsers(analysis) {
  // Estimación basada en perfiles afectados y severidad
  // Tijuana tiene ~170,000 personas con discapacidad motriz
  const basePopulation = 170000;
  const profileMultiplier = analysis.affectedProfiles.length * 0.15;
  const severityMultiplier = analysis.severity / 10;
  return Math.round(basePopulation * profileMultiplier * severityMultiplier);
}

function barrierTypeToNodeType(barrierType) {
  const map = {
    broken_ramp: 'ramp',
    missing_ramp: 'ramp',
    blocked_sidewalk: 'sidewalk',
    uneven_surface: 'sidewalk',
    no_curb_cut: 'crossing',
    construction: 'obstacle',
    parked_vehicle: 'obstacle',
    none: 'sidewalk'
  };
  return map[barrierType] || 'obstacle';
}

module.exports = { submitReport };
```

---

## HTML de prueba — fragmento

```html
<!-- test-report.html -->
<input type="file" id="foto" accept="image/*">
<button onclick="enviarReporte()">Reportar obstáculo</button>
<div id="resultado"></div>

<script type="module">
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.x.x/firebase-app.js';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'https://www.gstatic.com/firebasejs/10.x.x/firebase-storage.js';
import { getDatabase, ref as dbRef, onValue } from 'https://www.gstatic.com/firebasejs/10.x.x/firebase-database.js';

const app = initializeApp(FIREBASE_CONFIG);
const storage = getStorage(app);
const db = getDatabase(app);

async function enviarReporte() {
  const file = document.getElementById('foto').files[0];
  if (!file) return;
  
  // 1. Subir a Firebase Storage
  const storageRef = ref(storage, `reports/${Date.now()}_${file.name}`);
  await uploadBytes(storageRef, file);
  const photoUrl = await getDownloadURL(storageRef);
  
  // 2. Obtener ubicación GPS
  const pos = await new Promise(resolve => navigator.geolocation.getCurrentPosition(resolve));
  
  // 3. Enviar a Cloud Function
  const res = await fetch('https://us-central1-vialibretj.cloudfunctions.net/reportSubmit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      photoUrl,
      lat: pos.coords.latitude,
      lng: pos.coords.longitude,
      userId: 'test_user_wheelchair'
    })
  });
  
  const data = await res.json();
  document.getElementById('resultado').textContent = JSON.stringify(data, null, 2);
}

// Listener en tiempo real — ver nuevos reportes en el mapa
onValue(dbRef(db, 'reports'), snapshot => {
  const reports = snapshot.val() || {};
  // Actualizar markers en el mapa con los nuevos reportes
  updateMapMarkers(reports);
});
</script>
```

---

## Notas de implementación

- **Confianza baja (confidence < 0.6)**: marcar como `requiresHumanReview: true`. No bloquear el flujo — el reporte se guarda igual pero con una bandera.
- **Fire and forget para BigQuery**: el usuario no debe esperar la escritura en BigQuery. Usar `.catch(console.error)` y responder al cliente antes de que termine.
- **Foto en Storage, no en body**: nunca enviar imágenes en base64 al endpoint. Cloud Functions tienen límite de 10MB en el body.
- **Ticket correlativo**: el ID `TJ-YYYY-NNNN` requiere consultar BigQuery para el conteo. Si BigQuery falla, usar timestamp como fallback.
- **barrierType "none"**: cuando Gemini no detecta barrera, no crear nodo de obstáculo — ignorar el reporte silenciosamente o pedir confirmación al usuario.
