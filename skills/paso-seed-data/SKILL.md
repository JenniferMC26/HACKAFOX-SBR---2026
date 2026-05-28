---
name: vialibretj-seed-data
description: >
  Inicializa Firebase Realtime Database y BigQuery con datos semilla de Tijuana
  para el proyecto VíaLibre TJ. Úsalo cuando necesites poblar la base de datos por
  primera vez, reiniciar los datos de prueba, agregar nodos verificados en campo con
  fotos reales, o generar nodos estimados para demo. Cubre la inserción de nodos en
  /accessibility_layer (field_verified y estimated), patrones temporales en
  temporal_patterns (clave para Ruta Viva), y usuarios de prueba en /users.
  También aplica cuando el usuario diga "necesito datos de prueba", "quiero resetear
  la BD", "poblar Firebase", "seed BigQuery", "verificar nodo con foto" o
  "salir a tomar fotos de accesibilidad".
---

# VíaLibre TJ — Seed Data

Este skill guía la inicialización completa de Firebase Realtime DB y BigQuery.
Los nodos de accesibilidad tienen dos orígenes posibles: **verificados en campo**
(foto real tomada en el lugar) o **estimados** (aproximación para demo del hackathon).

## Contexto del proyecto

- **Firebase Realtime DB**: nodos de accesibilidad, reportes, sesiones de crisis, usuarios
- **BigQuery dataset**: `vialibretj` con tablas `accessibility_reports`, `temporal_patterns`, `civic_tickets`
- **Objetivo del seed**: que Ruta Viva tenga patrones históricos, que el mapa tenga nodos
  reales, y que el HTML de prueba muestre comportamiento creíble en la demo del hackathon

---

## Qué es un nodo de accesibilidad

Un nodo NO es una ruta de camión — es un **punto físico en la banqueta** que registra
si una rampa, cruce o entrada a un edificio es accesible o no. Ejemplos:
- "La entrada del IMSS Zona Río tiene rampa funcional → score 8"
- "La banqueta frente al Mercado Hidalgo está bloqueada por ambulantes → score 2"
- "El cruce en Constitución tiene botón peatonal → score 9"

El mapa de rutas de transporte (Google My Maps) sirve como **referencia** para saber
en qué calles poner nodos — las calles con paradas son las que más caminan los usuarios.

---

## Dos tipos de nodos

### `field_verified` — verificados con foto real

El equipo va físicamente al lugar, toma una foto con la cámara del teléfono, y corre
el script `verify-node.js` al regresar a la laptop. No se necesita servidor ni internet
en la calle — solo la cámara nativa del teléfono y anotar las coordenadas GPS.

**Flujo completo:**

```
En la calle:
  1. Abrir Google Maps, mantener presionado el punto → copiar coordenadas
  2. Tomar foto con cámara nativa del teléfono (sin abrir ninguna app del proyecto)
  3. Anotar en papel o notas: nodeId, lat, lng, tipo (ramp/sidewalk/entrance/crossing)

De regreso en la laptop:
  4. Copiar fotos a seed/fotos/
  5. node seed/verify-node.js --photo ./fotos/imss_entrada.jpg \
       --lat 32.5248 --lng -117.0284 --id node_imss_zonario_entrada
  6. Gemini analiza la foto y propone el score
  7. El equipo acepta (Enter) o corrige el score manualmente
  8. El nodo se guarda en Firebase con source: "field_verified"
```

### `estimated` — aproximados para demo

Nodos con coordenadas reales de Tijuana pero scores aproximados basados en
conocimiento general de esas zonas. Suficientes para la demo del hackathon.
Se insertan con `source: "estimated"` para distinguirlos de los verificados.

---

## Estructura de cada nodo en Firebase

```json
{
  "nodeId": "node_imss_zonario_entrada",
  "lat": 32.5248,
  "lng": -117.0284,
  "type": "ramp | crossing | sidewalk | obstacle | entrance",
  "accessible": true,
  "score": 8,
  "source": "field_verified | estimated",
  "verifiedBy": "team | null",
  "verifiedAt": "2025-05-28T10:00:00Z",
  "photoUrl": "gs://vialibretj.appspot.com/seed/imss_entrada.jpg | null",
  "geminiAnalysis": { ... },
  "lastReported": "2025-05-28T10:00:00Z",
  "reportCount": 0,
  "barrierType": null
}
```

---

## Script `verify-node.js` — para nodos field_verified

```javascript
// seed/verify-node.js
// Uso: node verify-node.js --photo ./fotos/imss_entrada.jpg
//                          --lat 32.5248 --lng -117.0284
//                          --id node_imss_zonario_entrada
//
// No requiere servidor corriendo. Llama directo a Gemini API y Firebase Admin SDK
// desde la laptop. Las fotos se toman en campo con la cámara nativa del teléfono.

const admin = require('firebase-admin');
const { analyzeBarrierPhoto } = require('../functions/src/reports/geminiVision');
const readline = require('readline');
const path = require('path');

const args = parseArgs(process.argv.slice(2));

admin.initializeApp({
  credential: admin.credential.cert(require('../serviceAccountKey.json')),
  databaseURL: 'https://vialibretj-default-rtdb.firebaseio.com',
  storageBucket: 'vialibretj.appspot.com'
});

async function verifyAndSeedNode({ photoPath, lat, lng, nodeId }) {
  console.log(`\n📍 Procesando nodo: ${nodeId}`);
  console.log(`   Ubicación: ${lat}, ${lng}`);
  console.log(`   Foto: ${path.basename(photoPath)}\n`);

  // 1. Subir foto a Firebase Storage
  const bucket = admin.storage().bucket();
  await bucket.upload(photoPath, { destination: `seed/${nodeId}.jpg` });
  const photoUrl = `gs://${bucket.name}/seed/${nodeId}.jpg`;
  console.log('☁️  Foto subida a Storage');

  // 2. Llamar a Gemini Vision — mismo pipeline que Puente Ciudadano
  console.log('🤖 Analizando con Gemini Vision...\n');
  const analysis = await analyzeBarrierPhoto(photoUrl);

  // Gemini devuelve severity del 1 al 10:
  //   1  → obstáculo casi imperceptible (grieta pequeña)
  //   3  → dificulta el paso pero no lo impide (pendiente alta, banqueta angosta)
  //   5  → paso con dificultad considerable (rampa dañada pero usable con ayuda)
  //   7  → prácticamente intransitable para silla de ruedas
  //   10 → completamente bloqueado (escalones sin rampa, obra total)
  //
  // El score de accesibilidad (0-10) se deriva invirtiendo el severity:
  //   score = 10 - severity
  //
  // Ejemplos:
  //   severity 2  → score 8  (muy accesible)
  //   severity 5  → score 5  (accesibilidad media)
  //   severity 8  → score 2  (muy inaccesible)
  //
  // El umbral accessible: true/false se fija en score >= 5
  // (el paso es posible aunque difícil)
  const geminiScore = 10 - analysis.severity;

  console.log('📊 Análisis de Gemini:');
  console.log(`   Tipo de barrera : ${analysis.barrierType}`);
  console.log(`   Severity        : ${analysis.severity}/10`);
  console.log(`   Score calculado : ${geminiScore}/10`);
  console.log(`   Pasable         : ${analysis.passable}`);
  console.log(`   Afecta a        : ${analysis.affectedProfiles?.join(', ')}`);
  console.log(`   Descripción     : ${analysis.description}`);
  console.log(`   Confianza       : ${Math.round(analysis.confidence * 100)}%\n`);

  if (analysis.confidence < 0.6) {
    console.log('⚠️  Confianza baja — revisa si la foto está clara y bien encuadrada\n');
  }

  // 3. Confirmar o corregir el score manualmente
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  rl.question(`¿Score correcto? (Enter para aceptar ${geminiScore}, o escribe el score real 1-10): `, async (input) => {
    // Si el equipo no escribe nada → acepta el score de Gemini
    // Si escribe un número → lo usa como override manual
    const finalScore = input.trim() ? parseInt(input.trim()) : geminiScore;

    // 4. Guardar en Firebase con flag field_verified
    await admin.database().ref(`accessibility_layer/${nodeId}`).set({
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      type: inferType(analysis.barrierType),
      accessible: finalScore >= 5,
      score: finalScore,
      source: 'field_verified',
      verifiedBy: 'team',
      verifiedAt: new Date().toISOString(),
      photoUrl,
      geminiAnalysis: analysis,
      barrierType: analysis.barrierType === 'none' ? null : analysis.barrierType,
      lastReported: new Date().toISOString(),
      reportCount: 0
    });

    console.log(`\n✅ Nodo "${nodeId}" guardado — score final: ${finalScore}/10`);
    rl.close();
    process.exit(0);
  });
}

function inferType(barrierType) {
  const map = {
    broken_ramp: 'ramp', missing_ramp: 'ramp',
    blocked_sidewalk: 'sidewalk', uneven_surface: 'sidewalk',
    no_curb_cut: 'crossing', construction: 'obstacle',
    parked_vehicle: 'obstacle', none: 'sidewalk'
  };
  return map[barrierType] || 'sidewalk';
}

function parseArgs(args) {
  const result = {};
  for (let i = 0; i < args.length; i += 2) {
    result[args[i].replace('--', '')] = args[i + 1];
  }
  return result;
}

verifyAndSeedNode({
  photoPath: args.photo,
  lat: args.lat,
  lng: args.lng,
  nodeId: args.id
});
```

---

## Paso 1 — Nodos semilla (20 nodos estimados + los que verifiques en campo)

Recomendación para el hackathon: verificar en campo **5-6 puntos clave** de la zona demo
y dejar el resto como `estimated`. En el pitch puedes mostrar las fotos reales.

### Nodos a verificar en campo primero (mayor impacto en demo)

| nodeId | lat | lng | Por qué prioritario |
|--------|-----|-----|---------------------|
| node_imss_zonario_entrada | 32.5248 | -117.0284 | Destino frecuente de usuarios |
| node_hospital_general_entrada | 32.5189 | -117.0289 | Destino crítico de salud |
| node_rampa_destruida_av4 | 32.5311 | -117.0362 | Caso de barrera severa — impacto visual en demo |
| node_banqueta_rota_calle2 | 32.5300 | -117.0350 | Caso de barrera severa |
| node_semaforo_constitucion | 32.5310 | -117.0340 | Caso de cruce accesible |
| node_parada_ruta3_constitucion | 32.5298 | -117.0335 | Parada de transporte |

### Nodos estimados (insertar con `firebase-seed.js`)

| nodeId | lat | lng | type | score | Notas |
|--------|-----|-----|------|-------|-------|
| node_imss_zonario_banqueta | 32.5245 | -117.0282 | sidewalk | 6 | Estimado |
| node_mercado_hidalgo_acceso | 32.5305 | -117.0349 | entrance | 3 | Estimado |
| node_mercado_hidalgo_calle | 32.5308 | -117.0352 | sidewalk | 2 | Estimado |
| node_revolucion_av_norte | 32.5320 | -117.0372 | sidewalk | 7 | Estimado |
| node_revolucion_av_sur | 32.5295 | -117.0358 | sidewalk | 6 | Estimado |
| node_hospital_general_estacion | 32.5192 | -117.0291 | crossing | 7 | Estimado |
| node_cecut_paseo_heroes | 32.5248 | -117.0074 | sidewalk | 8 | Estimado |
| node_cecut_entrada | 32.5251 | -117.0072 | entrance | 9 | Estimado |
| node_sat_tijuana_entrada | 32.5212 | -117.0198 | entrance | 7 | Estimado |
| node_banco_azteca_revo | 32.5316 | -117.0368 | entrance | 4 | Estimado |
| node_farmacia_similares_centro | 32.5302 | -117.0341 | entrance | 6 | Estimado |
| node_parada_ruta664_sanchez | 32.5240 | -117.0278 | crossing | 7 | Estimado |
| node_cruce_seguro_av9 | 32.5180 | -117.0260 | crossing | 8 | Estimado |
| node_centro_comunitario_norte | 32.5350 | -117.0300 | entrance | 7 | Estimado |

### Script `firebase-seed.js` — para nodos estimados

```javascript
// seed/firebase-seed.js
// Inserta los nodos estimados (sin foto real). Correr desde la laptop, no requiere servidor.
// Uso: node seed/firebase-seed.js

const admin = require('firebase-admin');
const nodes = require('./estimated-nodes.json');

admin.initializeApp({
  credential: admin.credential.cert(require('../serviceAccountKey.json')),
  databaseURL: 'https://vialibretj-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function seedEstimatedNodes() {
  const ref = db.ref('accessibility_layer');
  const updates = {};

  nodes.forEach(node => {
    updates[node.nodeId] = {
      lat: node.lat,
      lng: node.lng,
      type: node.type,
      accessible: node.score >= 5,
      score: node.score,
      source: 'estimated',          // distingue de field_verified
      verifiedBy: null,
      verifiedAt: null,
      photoUrl: null,
      geminiAnalysis: null,
      barrierType: node.score < 5 ? 'unknown' : null,
      lastReported: new Date().toISOString(),
      reportCount: 0
    };
  });

  await ref.update(updates);
  console.log(`✅ ${nodes.length} nodos estimados insertados en /accessibility_layer`);
}

seedEstimatedNodes().then(() => process.exit(0));
```

---

## Paso 2 — Seed de BigQuery `temporal_patterns`

```python
# seed/bigquery_seed.py
# Uso: python seed/bigquery_seed.py
# No requiere servidor. Llama directo a BigQuery con las credenciales del proyecto.

from google.cloud import bigquery

client = bigquery.Client(project='vialibretj')
table_id = 'vialibretj.temporal_patterns'

def generate_patterns():
    rows = []
    nodes = [
        {'lat': 32.5305, 'lng': -117.0349, 'name': 'mercado_hidalgo'},
        {'lat': 32.5248, 'lng': -117.0284, 'name': 'imss_zonario'},
        {'lat': 32.5320, 'lng': -117.0372, 'name': 'av_revolucion'},
        {'lat': 32.5298, 'lng': -117.0335, 'name': 'parada_ruta3'},
        {'lat': 32.5307, 'lng': -117.0349, 'name': 'catedral'},
    ]
    for node in nodes:
        for dow in range(7):
            for hour in range(24):
                score = base_score(node['name'], dow, hour)
                rows.append({
                    'lat': node['lat'], 'lng': node['lng'],
                    'hour_of_day': hour, 'day_of_week': dow,
                    'accessibility_score': score,
                    'event_flag': event_flag(node['name'], dow, hour),
                    'report_count': max(0, int((1 - score) * 10))
                })
    return rows

def base_score(name, dow, hour):
    score = 0.8
    if name == 'mercado_hidalgo':
        if dow == 2 and 10 <= hour <= 14: score = 0.2   # miércoles tianguis
        elif dow == 5 and 8 <= hour <= 16: score = 0.35 # sábado mercado
    if name == 'catedral' and dow == 6 and 8 <= hour <= 12: score = 0.3
    if name == 'parada_ruta3' and dow < 5 and hour in [7, 8, 17, 18, 19]: score = 0.4
    if 0 <= hour <= 5: score = min(score + 0.15, 1.0)   # madrugada: siempre alta
    return round(score, 2)

def event_flag(name, dow, hour):
    if name == 'mercado_hidalgo' and dow == 2 and 10 <= hour <= 14: return 'market_day'
    if name == 'catedral' and dow == 6 and 8 <= hour <= 12: return 'church'
    if name == 'parada_ruta3' and dow < 5 and hour in [7, 8, 17, 18, 19]: return 'rush_hour'
    return 'none'

rows = generate_patterns()
errors = client.insert_rows_json(table_id, rows)
print(f"✅ {len(rows)} patrones insertados" if not errors else f"❌ {errors}")
```

---

## Paso 3 — Seed de usuarios de prueba

```javascript
// seed/users-seed.js
const users = {
  test_user_wheelchair: {
    profile: { mobilityType: 'wheelchair', avoidSteps: true, avoidSlopes: true,
               slopeMaxPercent: 6, emergencyContacts: ['test_user_contact'] }
  },
  test_user_elderly: {
    profile: { mobilityType: 'elderly', avoidSteps: true, avoidSlopes: false,
               slopeMaxPercent: 10, emergencyContacts: ['test_user_contact'] }
  },
  test_user_contact: {
    profile: { mobilityType: 'none', avoidSteps: false, avoidSlopes: false,
               slopeMaxPercent: 100, emergencyContacts: [] }
  }
};
await admin.database().ref('users').update(users);
```

---

## Orden de ejecución

```bash
# 1. Nodos estimados (no requiere salir a la calle)
node seed/firebase-seed.js

# 2. Patrones temporales para Ruta Viva
python seed/bigquery_seed.py

# 3. Usuarios de prueba
node seed/users-seed.js

# 4. Nodos verificados en campo (correr una vez por foto, al regresar de la calle)
node seed/verify-node.js --photo ./fotos/imss_entrada.jpg \
  --lat 32.5248 --lng -117.0284 --id node_imss_zonario_entrada
```

## Errores comunes

- **"Permission denied" en Firebase**: verificar que `serviceAccountKey.json` tenga rol `Firebase Admin`
- **"Table not found" en BigQuery**: crear el dataset `vialibretj` y las tablas antes de insertar
- **Seed duplicado**: `update()` en Firebase sobreescribe — es seguro correr varias veces
- **Foto borrosa / confianza baja**: retomar la foto con mejor luz y encuadre horizontal
