# Paso — Plan de Implementación

Plataforma de ruteo accesible en tiempo real para Tijuana. Backend en Node.js con
Firebase Cloud Functions. Frontend temporal: HTML plano para probar la lógica.
Frontend final: Flutter (fuera del alcance de este plan).

---

## Stack

| Capa | Tecnología |
|------|-----------|
| API | Firebase Cloud Functions (Node.js 20) |
| Base de datos en tiempo real | Firebase Realtime Database |
| Almacenamiento de fotos | Firebase Storage |
| Analítica e historial | Google BigQuery |
| Análisis de imágenes | Gemini Vision API (`gemini-2.5-flash`) |
| Ruteo y mapas | Google Maps Routes API + Places API |
| Frontend de prueba | HTML plano + Firebase JS SDK v10 + Google Maps JS API |
| Entorno de desarrollo | Docker + Docker Compose (3 Windows + 1 macOS) |

---

## Estructura de carpetas

```
Paso/                               # Raíz del proyecto (repo)
├── CLAUDE.md                       # Este archivo — plan de implementación
├── skills/                         # Skills de referencia por feature
│   ├── paso-seed-data/
│   ├── paso-routing-engine/
│   ├── paso-puente-ciudadano/
│   ├── paso-ruta-viva/
│   ├── paso-navegador-voz/
│   └── paso-modo-crisis/
└── backend/                        # TODO el código backend vive aquí
    ├── functions/
    │   ├── src/
    │   │   ├── shared/
    │   │   │   ├── clients.js          # Firebase Admin + BigQuery inicializados una sola vez
    │   │   │   ├── nodeUtils.js        # Búsqueda y actualización de nodos en /accessibility_layer
    │   │   │   └── constants.js        # score = 10 - severity, umbrales de perfil, TTL de cache, etc.
    │   │   ├── routes/
    │   │   │   └── routing.js          # Motor de ruteo accesible (core)
    │   │   ├── reports/
    │   │   │   ├── report.js           # Puente Ciudadano — submit de reportes
    │   │   │   └── geminiVision.js     # Wrapper Gemini Vision API
    │   │   ├── ruta-viva/
    │   │   │   └── prediction.js       # Score predictivo temporal con BigQuery
    │   │   ├── voice/
    │   │   │   └── conversation.js     # Navegador Sin Pantalla — llama routing.js por import directo
    │   │   └── crisis/
    │   │       └── crisis.js           # Modo Crisis — protocolo de emergencia
    │   ├── index.js                    # Registro de Cloud Functions + CORS
    │   └── package.json
    ├── seed/
    │   ├── firebase-seed.js            # Inserta nodos estimados en Firebase
    │   ├── users-seed.js               # Inserta usuarios de prueba
    │   ├── verify-node.js              # Verifica nodo con foto real (field_verified)
    │   ├── upload-field-photos.js      # Sube fotos de campo y verifica nodos
    │   ├── bigquery_seed.py            # Inserta temporal_patterns en BigQuery
    │   ├── estimated-nodes.json        # Data de los 14 nodos estimados
    │   ├── field-captures.json         # Nodos a verificar en campo (6 prioritarios)
    │   └── fotos/                      # Fotos tomadas en campo (gitignore)
    ├── public/
    │   ├── index.html                  # HTML de prueba — pestañas por feature
    │   └── firebase-config.js          # Config pública del SDK cliente
    ├── Dockerfile                      # Imagen: Node 20 + Python + Java + Firebase CLI
    ├── docker-compose.yml              # Servicios: emulator + seed runner
    ├── .dockerignore
    ├── firebase.json
    ├── serviceAccountKey.json          # NO commitear — credenciales Firebase Admin
    └── .env                            # NO commitear — API keys
```

---

## Variables de entorno requeridas (`backend/.env`)

```bash
GEMINI_API_KEY=...
GOOGLE_MAPS_API_KEY=...           # Habilitar: Routes API, Places API, Maps JS API
FIREBASE_DATABASE_URL=https://paso-default-rtdb.firebaseio.com
GOOGLE_CLOUD_PROJECT=paso
```

El archivo `serviceAccountKey.json` va dentro de `backend/`.
El `.env` también va dentro de `backend/`.
Nunca commitear ninguno de los dos.

---

## Estructura de Firebase Realtime Database

```
/accessibility_layer/{nodeId}
  lat, lng, type, accessible, score (0-10)
  geohash                             # precision 7 (~150m) — requerido para queries por rango
  source: "field_verified" | "estimated"
  barrierType, lastReported, reportCount
  photoUrl, geminiAnalysis (solo en field_verified)

/reports/{reportId}
  userId, lat, lng, photoUrl
  geminiAnalysis: { barrierType, severity, passable, affectedProfiles, confidence }
  status: "pending" | "reviewed" | "resolved"
  createdAt, ticketId (si severity >= 7)

/crisis_sessions/{sessionId}
  userId, userProfile, startedAt
  currentLat, currentLng, status: "active" | "resolved"
  nearestSafePoint: { name, lat, lng, distanceMeters }
  alternativeRoute, alertedContacts[]

/users/{uid}
  profile: { mobilityType, avoidSteps, avoidSlopes, slopeMaxPercent, emergencyContacts[] }
  notifications/{notifId}: { type, fromUserId, sessionId, lat, lng, read }

/counters/ticketSeq                   # INTEGER — incrementado con transaction() al crear cada ticket
```

---

## Tablas BigQuery (`dataset: paso`)

```sql
-- accessibility_reports: espejo histórico de reportes ciudadanos
report_id, user_id, lat, lng, barrier_type, severity,
hour_of_day, day_of_week, weather_condition, reported_at, resolved_at

-- temporal_patterns: seed para Ruta Viva (predicción temporal)
lat, lng, hour_of_day (0-23), day_of_week (0=lunes),
accessibility_score (0.0-1.0), event_flag, report_count

-- civic_tickets: tickets formales para municipio (severity >= 7)
ticket_id (PASO-YYYY-NNNN), report_id, lat, lng,
barrier_type, severity, photo_url, gemini_description,
affected_users_estimate, created_at, assigned_to, status
```

---

## Entorno Docker (desarrollo multi-máquina)

El proyecto corre dentro de Docker para garantizar el mismo entorno en
3 Windows y 1 macOS. Nunca se instala Firebase CLI ni Node directamente
en la máquina host — todo va dentro del contenedor.

### Prerequisitos (una vez por máquina)

1. Instalar **Docker Desktop**:
   - Windows: https://www.docker.com/products/docker-desktop — activar WSL2 si lo pide
   - macOS: misma página, versión Apple Silicon o Intel según el chip
2. Clonar el repo, entrar a `backend/` y crear el `.env` (ver sección de variables de entorno)
3. Colocar `serviceAccountKey.json` dentro de `backend/` (nunca commitear)

### Comandos esenciales

> **Todos los comandos Docker se corren desde la carpeta `backend/`**

```bash
# Primero, moverse a la carpeta backend
cd backend/

# Primera vez — construir la imagen (también al cambiar Dockerfile o package.json)
docker compose build

# Levantar el emulador local de Firebase
docker compose up

# Levantar en background
docker compose up -d

# Ver logs en tiempo real (si está en background)
docker compose logs -f emulator

# Apagar todo
docker compose down
```

### Correr scripts de seed

```bash
# Desde backend/
cd backend/

# Insertar nodos estimados en Firebase Emulator
docker compose run seed node seed/firebase-seed.js

# Insertar usuarios de prueba
docker compose run seed node seed/users-seed.js

# Insertar patrones temporales en BigQuery (prod — requiere credenciales reales)
docker compose run seed python3 seed/bigquery_seed.py

# Subir fotos de campo y verificar nodos (requiere fotos en seed/fotos/)
docker compose run seed node seed/upload-field-photos.js
```

### URLs del emulador local

| Servicio | URL |
|----------|-----|
| Emulator UI (panel visual) | http://localhost:4000 |
| Cloud Functions | http://localhost:5001/paso/us-central1/<fn> |
| Realtime Database | http://localhost:9000 |
| Storage | http://localhost:9199 |

### Apuntar el HTML de prueba al emulador

En `backend/public/firebase-config.js`, cuando se trabaje localmente, agregar después
de `initializeApp(firebaseConfig)`:

```javascript
// Solo en desarrollo local — comentar para producción
if (location.hostname === 'localhost') {
  connectDatabaseEmulator(db, 'localhost', 9000);
  connectStorageEmulator(storage, 'localhost', 9199);
  connectFunctionsEmulator(functions, 'localhost', 5001);
}
```

### Notas de seguridad del contenedor

- `serviceAccountKey.json` y `.env` están en `.dockerignore` — **nunca entran en la imagen**
- Se montan como volumen en tiempo de ejecución, no se copian al hacer `build`
- `seed/fotos/` también está excluido — las fotos pesadas no van en la imagen

---

## Orden de implementación

Implementar en este orden exacto. Cada paso desbloquea el siguiente.

### Fase 0 — Setup (antes de escribir código)

```bash
# 1. Crear proyecto en Firebase Console con nombre "paso"
#    - Habilitar Realtime Database (modo test por ahora)
#    - Habilitar Storage
#    - Habilitar Authentication → activar proveedor "Anónimo"
#    - Descargar serviceAccountKey.json → colocarlo en backend/

# 2. Habilitar APIs en Google Cloud Console
#    - Routes API
#    - Places API (New)
#    - Maps JavaScript API
#    - Gemini API (via AI Studio o Google Cloud)

# 3. Crear dataset y tablas en BigQuery
#    Correr backend/seed/queries.sql desde la consola de BQ o con bq CLI
#    Incluye DDL de las 3 tablas: accessibility_reports, temporal_patterns, civic_tickets

# 4. Inicializar Firebase dentro de backend/
cd backend/
firebase init functions   # Node.js 20, JavaScript
npm install --save @google-cloud/bigquery @google/generative-ai cors firebase-admin ngeohash

# 5. Construir el contenedor Docker
docker compose build
```

---

### Fase 1 — Seed data

**Skill de referencia**: `skills/paso-seed-data/SKILL.md`

```bash
# Desde backend/
cd backend/
docker compose run seed node seed/firebase-seed.js
docker compose run seed node seed/users-seed.js
docker compose run seed python3 seed/bigquery_seed.py

# Para subir fotos tomadas en campo:
docker compose run seed node seed/upload-field-photos.js
```

**Verificación**: abrir Firebase Console → Realtime Database → confirmar que
`/accessibility_layer` tiene ~20 nodos y `/users` tiene los 3 usuarios de prueba.

---

### Fase 2 — Motor de ruteo (`POST /routing/accessible`)

**Skill de referencia**: `skills/paso-routing-engine/SKILL.md`

Archivo: `backend/functions/src/routes/routing.js`

Lógica:
1. Llama Routes API con `travelMode: WALK`
2. Decodifica el polyline resultante
3. Consulta `/accessibility_layer` en Firebase buscando nodos en el bounding box de la ruta
4. Calcula `accessibilityScore` promedio y genera `warnings[]`
5. Aplica umbrales diferenciados por perfil (`wheelchair` más estricto que `elderly`)
6. Si `arrivalTime` está presente, llama a `getRutaVivaScore()` e inyecta el ajuste

**Test con HTML**: formulario con lat/lng origen, lat/lng destino y selector de perfil.
La respuesta dibuja una polyline en el mapa y muestra markers rojos en los warnings.

```bash
firebase deploy --only functions:routingAccessible
```

---

### Fase 3 — Puente Ciudadano (`POST /reports/submit`)

**Skill de referencia**: `skills/paso-puente-ciudadano/SKILL.md`

Archivos: `backend/functions/src/reports/geminiVision.js` + `backend/functions/src/reports/report.js`

Lógica:
1. Verificar `idToken` del header `Authorization: Bearer <token>` con `admin.auth().verifyIdToken()`
2. El cliente HTML sube la foto a Firebase Storage y envía la `photoUrl`
3. Cloud Function descarga la foto y la envía a Gemini Vision con el prompt estructurado
4. Gemini devuelve JSON: `barrierType`, `severity` (1-10), `passable`, `affectedProfiles`, `confidence`
5. Si `confidence < 0.6` → marcar `requiresHumanReview: true`
6. Actualizar `/accessibility_layer` — si hay nodo cercano (< 30m) actualizarlo, si no crear uno nuevo (incluir `geohash`)
7. Escribir en BigQuery `accessibility_reports` (fire and forget — no bloquea la respuesta)
8. Si `severity >= 7` → obtener ticket ID con `db.ref('/counters/ticketSeq').transaction(n => n + 1)`,
   formatear como `PASO-YYYY-NNNN`, insertar en BigQuery `civic_tickets`

**Score derivado de Gemini**: `score = 10 - severity`
(severity 2 → score 8 muy accesible; severity 8 → score 2 muy inaccesible)

**Test con HTML**: input de archivo de imagen + botón → mostrar JSON de respuesta +
ver el nuevo nodo aparecer en el mapa en tiempo real vía Firebase listener.

```bash
firebase deploy --only functions:reportSubmit
```

---

### Fase 4 — Ruta Viva (`GET /ruta-viva/score`)

**Skill de referencia**: `skills/paso-ruta-viva/SKILL.md`

Archivo: `backend/functions/src/ruta-viva/prediction.js`

Lógica:
1. Extraer `hour_of_day` y `day_of_week` del `arrivalTime` ISO 8601
2. Query BigQuery en `temporal_patterns` con radio ~200m alrededor del punto
3. Si `dataPoints < 3` → fallback gracioso con `applied: false` (no inventar scores)
4. Combinar 70% histórico BQ + 30% Firebase reciente (últimas 2h)
5. Cache en memoria con TTL 30 min por `(lat_rounded, lng_rounded, hour, dow)`

Integración con Fase 2: el motor de ruteo llama `getRutaVivaScore()` si recibe `arrivalTime`.

**Test con HTML**: selector `datetime-local` → mismo punto a distintas horas →
score debe bajar los miércoles 10am en Mercado Hidalgo.

```bash
firebase deploy --only functions:rutaVivaScore
```

---

### Fase 5 — Navegador Sin Pantalla (`POST /voice/query`)

**Skill de referencia**: `skills/paso-navegador-voz/SKILL.md`

Archivo: `backend/functions/src/voice/conversation.js`

Lógica:
1. Gemini interpreta la intención del usuario (frases ambiguas como "el IMSS de aquí cerca")
2. Si `intent = navigate` → Places API resuelve el destino a coordenadas
3. Motor de ruteo (Fase 2) calcula la ruta
4. Segundo llamado a Gemini convierte la ruta técnica a instrucciones de voz en español
5. Mantener `conversationHistory[]` en el cliente entre llamadas

**Test con HTML**: textarea que simula la voz (el usuario escribe como si hablara).
`SpeechSynthesisUtterance` sintetiza la respuesta en audio.

```bash
firebase deploy --only functions:voiceQuery
```

---

### Fase 6 — Modo Crisis (3 endpoints)

**Skill de referencia**: `skills/paso-modo-crisis/SKILL.md`

Archivo: `backend/functions/src/crisis/crisis.js`

Endpoints:
- `POST /crisis/start` — busca punto seguro, notifica contactos, crea sesión
- `PUT /crisis/:id/update` — actualiza lat/lng cada 10s
- `DELETE /crisis/:id/resolve` — cierra la sesión

**Test con HTML**: dos pestañas del navegador simultáneas.
- Pestaña 1 (usuario varado): botón "Estoy varado" → ver punto seguro sugerido
- Pestaña 2 (contacto): Firebase `onValue()` actualiza el marker en tiempo real

```bash
firebase deploy --only functions:crisisStart,crisisUpdate,crisisResolve
```

---

## Cómo funciona el HTML de prueba

El `backend/public/index.html` tiene una pestaña por feature. No usa frameworks — solo:
- Firebase JS SDK v10 (módulos ES) para Storage, Realtime DB y Auth
- `fetch()` para llamar a las Cloud Functions
- Google Maps JS API para renderizar el mapa y las rutas

El cliente nunca tiene credenciales de servidor (Gemini, BigQuery, Maps Routes API).
Solo tiene la config pública de Firebase y la Maps JS API key (restringida por dominio).

---

## Skills disponibles por feature

Cada skill contiene la implementación detallada, el código completo y notas de implementación.
Consultar antes de implementar cada fase:

| Feature | Skill |
|---------|-------|
| Seed data y verificación en campo | `skills/paso-seed-data/SKILL.md` |
| Motor de ruteo accesible | `skills/paso-routing-engine/SKILL.md` |
| Puente Ciudadano (reportes + Gemini Vision) | `skills/paso-puente-ciudadano/SKILL.md` |
| Ruta Viva (predicción temporal) | `skills/paso-ruta-viva/SKILL.md` |
| Navegador Sin Pantalla (voz) | `skills/paso-navegador-voz/SKILL.md` |
| Modo Crisis (emergencia) | `skills/paso-modo-crisis/SKILL.md` |

---

## Módulos compartidos (`src/shared/`)

Toda la lógica transversal vive aquí. Ningún módulo de feature inicializa clientes
ni duplica lógica de nodos por su cuenta.

### `clients.js`
Inicializa Firebase Admin y el cliente de BigQuery **una sola vez** y los exporta.
Todos los demás módulos importan de aquí — nunca llaman a `admin.initializeApp()` por su cuenta.

```js
// Ejemplo de uso en cualquier módulo
const { db, bigquery } = require('../shared/clients');
```

### `nodeUtils.js`
Funciones reutilizables sobre `/accessibility_layer`:
- `findNodesInBoundingBox(bounds)` — usada por `routing.js`. RTDB no tiene queries geoespaciales
  nativos; se consulta por rango de geohash prefix (`orderByChild('geohash').startAt(prefix).endAt(prefix + '')`),
  luego se filtra en memoria por bounding box exacto.
- `findNearestNode(lat, lng, radiusMeters)` — usada por `report.js` (radio < 30m). Usa el mismo
  rango de geohash y filtra por distancia Haversine.
- `upsertNode(nodeData)` — actualiza nodo existente o crea uno nuevo; siempre calcula y persiste `geohash`.

### `constants.js`
Valores de negocio centralizados:
- `severityToScore(severity)` → `10 - severity` (única definición en todo el proyecto)
- Umbrales por perfil: `THRESHOLDS = { wheelchair: 6, elderly: 4, ... }`
- `RUTA_VIVA_CACHE_TTL_MS = 30 * 60 * 1000`
- `REPORT_NEARBY_RADIUS_METERS = 30`
- `RUTA_VIVA_BQ_WEIGHT = 0.7`, `RUTA_VIVA_FIREBASE_WEIGHT = 0.3`

---

## Seguridad

### Reglas de Firebase Realtime Database

Reemplazar las reglas "modo test" antes de cualquier deploy. Copiar en
Firebase Console → Realtime Database → Rules:

```json
{
  "rules": {
    "accessibility_layer": {
      ".read": true,
      ".write": false
    },
    "reports": {
      "$reportId": {
        ".read": "auth != null && data.child('userId').val() === auth.uid",
        ".write": "auth != null && !data.exists() && newData.child('userId').val() === auth.uid"
      }
    },
    "crisis_sessions": {
      "$sessionId": {
        ".read": "auth != null && data.child('userId').val() === auth.uid",
        ".write": false
      }
    },
    "users": {
      "$uid": {
        ".read":  "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid",
        "notifications": {
          ".write": false
        },
        "reportCount": {
          ".read": false,
          ".write": false
        }
      }
    },
    "counters": {
      ".read":  false,
      ".write": false
    }
  }
}
```

Notas de las reglas:
- `accessibility_layer` es lectura pública — datos de accesibilidad urbana son información abierta. Solo el Admin SDK escribe.
- Cada usuario solo lee y escribe sus propios reportes.
- `crisis_sessions` es escritura exclusiva del Admin SDK — create/update/delete se hacen únicamente desde Cloud Functions.
- `notifications`, `reportCount` y `counters` son de escritura (y lectura) exclusiva del Admin SDK.

---

### Reglas de Firebase Storage

Copiar en Firebase Console → Storage → Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /reports/{userId}/{allPaths=**} {
      allow read:  if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && request.resource.size < 10 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

Notas:
- Solo el dueño puede subir fotos a su carpeta `reports/{uid}/`.
- Tamaño máximo por foto: 10 MB.
- Solo se aceptan archivos de tipo `image/*`. Rechaza PDFs, scripts, etc.
- Cualquier ruta fuera de `reports/` está bloqueada.

---

### Rate limiting en `/reports/submit`

Antes de llamar a Gemini Vision, verificar en RTDB que el usuario no supere
5 reportes por hora. Esto previene costos descontrolados por abuso.

```js
// En report.js — antes de llamar geminiVision()
const hourKey = new Date().toISOString().slice(0, 13); // "2026-05-28T10"
const countRef = db.ref(`/users/${uid}/reportCount/${hourKey}`);
const snap = await countRef.transaction(n => (n || 0) + 1);
if (snap.snapshot.val() > 5) {
  return res.status(429).json({ error: 'Límite de reportes por hora alcanzado' });
}
```

---

### Validación de inputs

Cada Cloud Function debe validar su payload antes de procesarlo.

**`routing.js`** — coordenadas dentro del bounding box de Tijuana:
```js
const TJ_BOUNDS = { latMin: 32.4, latMax: 32.7, lngMin: -117.2, lngMax: -116.8 };
function isValidCoord(lat, lng) {
  return lat >= TJ_BOUNDS.latMin && lat <= TJ_BOUNDS.latMax
      && lng >= TJ_BOUNDS.lngMin && lng <= TJ_BOUNDS.lngMax;
}
// → 400 si origin o destination están fuera de bounds
```

**`report.js`** — la `photoUrl` debe pertenecer al bucket del proyecto:
```js
// El bucket por defecto cambió a `paso.firebasestorage.app` en proyectos nuevos.
// Confirmar en Firebase Console → Storage cuál aplica y setear en .env:
//   STORAGE_BUCKET=paso.appspot.com   (o paso.firebasestorage.app)
const bucket = process.env.STORAGE_BUCKET || admin.storage().bucket().name;
const STORAGE_PREFIX = `https://firebasestorage.googleapis.com/v0/b/${bucket}`;
if (!photoUrl.startsWith(STORAGE_PREFIX)) {
  return res.status(400).json({ error: 'photoUrl no pertenece al bucket autorizado' });
}
```

**`crisis.js`** — verificar ownership antes de actualizar o resolver:
```js
// En PUT /crisis/:id/update y DELETE /crisis/:id/resolve
const session = await db.ref(`/crisis_sessions/${sessionId}`).once('value');
if (!session.exists() || session.val().userId !== uid) {
  return res.status(403).json({ error: 'Sesión no encontrada o acceso denegado' });
}
```

---

### Checklist de seguridad antes de demo/deploy

- [ ] Reglas de RTDB actualizadas (salir de modo test)
- [ ] Reglas de Storage aplicadas
- [ ] `serviceAccountKey.json` y `.env` fuera del repo (verificar con `git status`)
- [ ] Maps JS API key restringida por dominio en Google Cloud Console
- [ ] Gemini API key sin restricciones de IP solo en desarrollo — agregar restricción en prod
- [ ] Rate limiting activo en `/reports/submit`
- [ ] Validación de coordenadas activa en `/routing/accessible`
- [ ] `STORAGE_BUCKET` en `.env` coincide con el bucket real del proyecto (verificar en Firebase Console → Storage)

---

## Notas generales

- **CORS**: siempre aplicar middleware `cors({ origin: true })` en todas las Cloud Functions
- **Fire and forget**: las escrituras en BigQuery no bloquean la respuesta al cliente
- **Foto en Storage primero**: nunca enviar imágenes en base64 al body de la Cloud Function
- **Score vs Severity**: definido en `shared/constants.js` como `severityToScore()`. Score alto = más accesible.
- **field_verified > estimated**: el motor de ruteo puede ponderar más los nodos verificados en campo
- **Timezone**: el cliente debe enviar ISO 8601 con offset explícito (`2026-05-28T10:00:00-07:00`),
  no "local time". `new Date(isoString)` en el servidor respeta el offset del string, no del servidor.
- **BigQuery latencia**: 1-3 segundos por query. Usar el cache de Ruta Viva siempre.
- **`conversation.js` llama `routing.js` por import directo**, no por HTTP — evita latencia y acoplamiento innecesario
- **Auth**: el cliente llama `signInAnonymously()` al cargar; adjunta el `idToken` en cada request como
  `Authorization: Bearer <token>`. Las Cloud Functions verifican con `admin.auth().verifyIdToken()`.
  Sin uid válido → 401.
- **Ticket ID atómico**: el counter vive en `/counters/ticketSeq` en RTDB. Se incrementa con
  `transaction()` antes de insertar en BigQuery. BigQuery no tiene transacciones de fila — nunca
  generar el ID allí.
- **Geohash**: todos los nodos en `/accessibility_layer` deben incluir `geohash` (precision 7, librería
  `ngeohash`). El seed lo calcula al insertar. Sin geohash los queries de bounding box traen toda la colección.
