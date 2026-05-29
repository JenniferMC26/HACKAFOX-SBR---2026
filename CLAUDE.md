# Paso — Plan de Implementación

Plataforma de ruteo accesible en tiempo real para Tijuana. Backend en Node.js con
Firebase Cloud Functions. Frontend temporal: HTML plano para probar la lógica.
Frontend final: Flutter (fuera del alcance de este plan).

---

## Stack

| Capa | Tecnología |
|------|-----------|
| API | Firebase Cloud Functions (Node.js 20) |
| Base de datos principal | Supabase PostgreSQL + PostGIS |
| Autenticación | Supabase Auth (proveedor anónimo) |
| Almacenamiento de fotos | Supabase Storage |
| Análisis de imágenes | Gemini Vision API (`gemini-2.5-flash`) |
| Ruteo y mapas | Google Maps Routes API + Places API |
| Frontend de prueba | HTML plano + Supabase JS SDK v2 + Google Maps JS API |
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
    │   │   │   ├── clients.js          # Cliente Supabase (service role) inicializado una sola vez
    │   │   │   ├── nodeUtils.js        # Búsqueda y actualización de nodos con PostGIS
    │   │   │   └── constants.js        # score = 10 - severity, umbrales de perfil, TTL de cache, etc.
    │   │   ├── routes/
    │   │   │   └── routing.js          # Motor de ruteo accesible (core)
    │   │   ├── reports/
    │   │   │   ├── report.js           # Puente Ciudadano — submit de reportes
    │   │   │   └── geminiVision.js     # Wrapper Gemini Vision API (sin cambios)
    │   │   ├── ruta-viva/
    │   │   │   └── prediction.js       # Score predictivo temporal con Supabase RPC ruta_viva_history
    │   │   ├── voice/
    │   │   │   └── conversation.js     # Navegador Sin Pantalla — llama routing.js por import directo
    │   │   └── crisis/
    │   │       └── crisis.js           # Modo Crisis — usa Supabase Realtime
    │   ├── index.js                    # Registro de Cloud Functions + CORS
    │   └── package.json
    ├── seed/
    │   ├── supabase-seed.js            # Inserta nodos estimados + patrones temporales en Supabase
    │   ├── users-seed.js               # Inserta usuarios de prueba en Supabase Auth
    │   ├── supabase-schema.sql         # DDL completo de tablas Supabase + RLS
    │   ├── estimated-nodes.json        # Data de los 14 nodos estimados
    │   └── field-captures.json         # Nodos a verificar en campo (6 prioritarios)
    ├── public/
    │   ├── index.html                  # HTML de prueba — pestañas por feature
    │   ├── supabase-config.js          # Cliente Supabase — importa de config.js
    │   └── config.example.js           # Plantilla — copiar a config.js (gitignored)
    ├── Dockerfile                      # Imagen: Node 22 + Temurin JRE 21
    ├── docker-compose.yml              # Servicios: emulator (Functions only) + seed runner
    ├── .dockerignore
    ├── firebase.json
    └── .env                            # NO commitear — API keys y credenciales Supabase
```

---

## Variables de entorno requeridas (`backend/.env`)

```bash
# Google APIs
GEMINI_API_KEY=...
GOOGLE_MAPS_API_KEY=...           # Maps JS API (mapa visual) — Routes API si se consigue

# Supabase (obtener en supabase.com → proyecto → Settings → API)
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=...          # service_role key — solo en backend, nunca en cliente
SUPABASE_ANON_KEY=...             # anon key — va en el frontend (supabase-config.js)
```

El `.env` va dentro de `backend/`. Nunca commitear.
`SUPABASE_SERVICE_KEY` tiene permisos de administrador — tratar como `serviceAccountKey.json`.

---

## Esquema Supabase (PostgreSQL + PostGIS)

Correr `backend/seed/supabase-schema.sql` desde el SQL Editor de Supabase (una sola vez).

```sql
-- Habilitar extensión geoespacial
CREATE EXTENSION IF NOT EXISTS postgis;

-- Tabla 1: nodos de accesibilidad urbana
CREATE TABLE public.accessibility_nodes (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  lat             FLOAT8 NOT NULL,
  lng             FLOAT8 NOT NULL,
  location        GEOGRAPHY(POINT, 4326),   -- generado en insert/update
  type            TEXT,
  accessible      BOOLEAN,
  score           INT CHECK (score BETWEEN 0 AND 10),
  source          TEXT DEFAULT 'estimated' CHECK (source IN ('field_verified','estimated')),
  barrier_type    TEXT,
  last_reported   TIMESTAMPTZ,
  report_count    INT DEFAULT 0,
  photo_url       TEXT,
  gemini_analysis JSONB,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla 2: reportes ciudadanos
CREATE TABLE public.reports (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id         TEXT NOT NULL,
  lat             FLOAT8 NOT NULL,
  lng             FLOAT8 NOT NULL,
  location        GEOGRAPHY(POINT, 4326),
  photo_url       TEXT,
  gemini_analysis JSONB,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','resolved')),
  ticket_id       TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla 3: sesiones de crisis
CREATE TABLE public.crisis_sessions (
  id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id             TEXT NOT NULL,
  user_profile        JSONB,
  started_at          TIMESTAMPTZ DEFAULT NOW(),
  current_lat         FLOAT8,
  current_lng         FLOAT8,
  current_location    GEOGRAPHY(POINT, 4326),
  status              TEXT DEFAULT 'active' CHECK (status IN ('active','resolved')),
  nearest_safe_point  JSONB,
  alternative_route   JSONB,
  alerted_contacts    JSONB DEFAULT '[]'::jsonb
);

-- Tabla 4: perfiles de usuario
CREATE TABLE public.user_profiles (
  uid                  TEXT PRIMARY KEY,
  mobility_type        TEXT,
  avoid_steps          BOOLEAN DEFAULT FALSE,
  avoid_slopes         BOOLEAN DEFAULT FALSE,
  slope_max_percent    FLOAT8 DEFAULT 8.0,
  emergency_contacts   JSONB DEFAULT '[]'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla 5: historial de reportes (reemplaza BigQuery accessibility_reports)
CREATE TABLE public.accessibility_reports (
  id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  report_id         TEXT NOT NULL,
  user_id           TEXT NOT NULL,
  lat               FLOAT8 NOT NULL,
  lng               FLOAT8 NOT NULL,
  location          GEOGRAPHY(POINT, 4326),
  barrier_type      TEXT,
  severity          INT,
  hour_of_day       INT,                -- 0–23
  day_of_week       INT,                -- 0=lunes … 6=domingo
  reported_at       TIMESTAMPTZ DEFAULT NOW(),
  resolved_at       TIMESTAMPTZ
);

-- Tabla 6: patrones temporales para Ruta Viva (reemplaza BigQuery temporal_patterns)
CREATE TABLE public.temporal_patterns (
  id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  lat                 FLOAT8 NOT NULL,
  lng                 FLOAT8 NOT NULL,
  location            GEOGRAPHY(POINT, 4326),
  hour_of_day         INT NOT NULL,     -- 0–23
  day_of_week         INT NOT NULL,     -- 0=lunes … 6=domingo
  accessibility_score FLOAT8 NOT NULL,  -- 0.0 inaccesible → 1.0 accesible
  event_flag          BOOLEAN DEFAULT FALSE,
  report_count        INT DEFAULT 0
);

-- Tabla 7: tickets formales para municipio (reemplaza BigQuery civic_tickets)
CREATE TABLE public.civic_tickets (
  id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  ticket_id               TEXT NOT NULL UNIQUE,  -- PASO-YYYY-NNNN
  report_id               TEXT NOT NULL,
  lat                     FLOAT8 NOT NULL,
  lng                     FLOAT8 NOT NULL,
  barrier_type            TEXT,
  severity                INT,
  photo_url               TEXT,
  gemini_description      TEXT,
  affected_users_estimate INT,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  assigned_to             TEXT,
  status                  TEXT DEFAULT 'open' CHECK (status IN ('open','assigned','resolved'))
);

-- Secuencia atómica para ticket IDs
CREATE SEQUENCE public.ticket_seq START 1;
```

---

## Entorno Docker (desarrollo multi-máquina)

El Docker ahora solo emula **Firebase Cloud Functions**. Supabase corre en la nube
(free tier) — no hay emulador local de Supabase.

### Prerequisitos (una vez por máquina)

1. Instalar **Docker Desktop** (activar WSL2 en Windows)
2. Crear proyecto en **supabase.com** y copiar las 3 variables al `.env`
3. Clonar el repo y correr `copy .env.example .env` desde `backend/`

### Comandos esenciales

```bash
cd backend/

# Primera vez
docker compose build

# Levantar el emulador de Functions
docker compose up -d

# Ver logs
docker compose logs -f emulator

# Apagar
docker compose down
```

### Correr scripts de seed

```bash
cd backend/

# Insertar nodos en Supabase (requiere SUPABASE_URL y SUPABASE_SERVICE_KEY en .env)
docker compose run --rm seed node seed/supabase-seed.js

# Insertar usuarios de prueba
docker compose run --rm seed node seed/users-seed.js
```

### URLs del emulador local

| Servicio | URL |
|----------|-----|
| Test console (5 pestañas) | http://localhost:5000 |
| Emulator UI | http://localhost:4000 |
| Cloud Functions | http://localhost:5001/paso/us-central1/<fn> |

### Apuntar el HTML de prueba al emulador de Functions

En `backend/public/supabase-config.js`, el cliente Supabase siempre apunta a producción.
Solo las Cloud Functions se redirigen al emulador local:

```javascript
// Solo en desarrollo local — comentar para producción
if (location.hostname === 'localhost') {
  // Supabase apunta a prod siempre (no tiene emulador local)
  // Solo redirigir las Cloud Functions al emulador
  const FUNCTIONS_BASE = 'http://localhost:5001/paso/us-central1';
}
```

---

## Orden de implementación

### Fase 0 — Setup (antes de escribir código)

```bash
# 1. Crear proyecto en supabase.com
#    - Copiar SUPABASE_URL, SUPABASE_SERVICE_KEY y SUPABASE_ANON_KEY al .env
#    - Ir al SQL Editor → pegar y correr backend/seed/supabase-schema.sql
#    - En Authentication → Providers → activar "Anonymous sign-ins"
#    - En Storage → crear bucket "reports" (público: false)
#    - En Database → Replication → activar tabla crisis_sessions

# 2. Obtener Gemini API key
#    - Ir a aistudio.google.com/app/apikey → crear key gratis

# 3. Inicializar Firebase Cloud Functions dentro de backend/
cd backend/
firebase init functions   # Node.js 20, JavaScript
npm install --save @google/generative-ai cors @supabase/supabase-js

# 4. Construir el contenedor Docker
docker compose build
```

---

### Fase 1 — Seed data

**Skill de referencia**: `skills/paso-seed-data/SKILL.md`

```bash
cd backend/
docker compose run --rm seed node seed/supabase-seed.js   # nodos + patrones temporales
docker compose run --rm seed node seed/users-seed.js
```

**Verificación**: Supabase Dashboard → Table Editor → `accessibility_nodes` debe tener
~14 nodos, `temporal_patterns` ~26 filas, y `user_profiles` los 3 usuarios de prueba.

---

### Fase 2 — Motor de ruteo (`POST /routing/accessible`)

**Skill de referencia**: `skills/paso-routing-engine/SKILL.md`

Archivo: `backend/functions/src/routes/routing.js`

Lógica:
1. Llama Routes API con `travelMode: WALK`
2. Decodifica el polyline resultante
3. Consulta `accessibility_nodes` en Supabase con PostGIS bounding box:
   ```sql
   SELECT * FROM accessibility_nodes
   WHERE ST_Within(location, ST_MakeEnvelope($lngMin,$latMin,$lngMax,$latMax,4326)::geography)
   ```
4. Calcula `accessibilityScore` promedio y genera `warnings[]`
5. Aplica umbrales por perfil (`wheelchair` más estricto que `elderly`)
6. Si `arrivalTime` presente → llama `getRutaVivaScore()` e inyecta el ajuste

```bash
firebase deploy --only functions:routingAccessible
```

---

### Fase 3 — Puente Ciudadano (`POST /reports/submit`)

**Skill de referencia**: `skills/paso-puente-ciudadano/SKILL.md`

Archivos: `backend/functions/src/reports/geminiVision.js` + `backend/functions/src/reports/report.js`

Lógica:
1. Verificar JWT de Supabase del header `Authorization: Bearer <token>`
2. El cliente HTML sube la foto a **Supabase Storage** bucket `reports/{uid}/` y envía la URL
3. Cloud Function descarga la foto y la envía a Gemini Vision
4. Gemini devuelve JSON: `barrierType`, `severity`, `passable`, `affectedProfiles`, `confidence`
5. Si `confidence < 0.6` → `requiresHumanReview: true`
6. Upsert en `accessibility_nodes` — si hay nodo a < 30m actualizarlo (PostGIS), si no crear uno:
   ```sql
   SELECT id FROM accessibility_nodes
   WHERE ST_DWithin(location, ST_Point($lng,$lat)::geography, 30)
   ORDER BY location <-> ST_Point($lng,$lat)::geography LIMIT 1
   ```
7. Insertar en `accessibility_reports` de Supabase (fire and forget)
8. Si `severity >= 7` → obtener ticket ID atómico con `SELECT nextval('ticket_seq')`,
   formatear como `PASO-YYYY-NNNN`, insertar en `civic_tickets` de Supabase

```bash
firebase deploy --only functions:reportSubmit
```

---

### Fase 4 — Ruta Viva (`GET /ruta-viva/score`)

**Skill de referencia**: `skills/paso-ruta-viva/SKILL.md`

Archivo: `backend/functions/src/ruta-viva/prediction.js`

Todo corre sobre Supabase — sin BigQuery. Lógica:
1. Extraer `hour_of_day` y `day_of_week` del `arrivalTime` ISO 8601
2. Query a `temporal_patterns` en Supabase con PostGIS radio ~200m:
   ```sql
   SELECT accessibility_score, event_flag, report_count
   FROM temporal_patterns
   WHERE hour_of_day = $hour AND day_of_week = $dow
   AND ST_DWithin(location, ST_Point($lng,$lat)::geography, 200)
   ```
3. Si `data.length < 3` → fallback con `applied: false`
4. Combinar 70% histórico (`temporal_patterns`) + 30% reportes recientes
   de `accessibility_reports` (últimas 2h, radio 200m)
5. Cache en memoria con TTL 30 min por `(lat_rounded, lng_rounded, hour, dow)`

```bash
firebase deploy --only functions:rutaVivaScore
```

---

### Fase 5 — Navegador Sin Pantalla (`POST /voice/query`)

**Skill de referencia**: `skills/paso-navegador-voz/SKILL.md`

Archivo: `backend/functions/src/voice/conversation.js`

**Sin cambios significativos** — llama `routing.js` por import directo. La verificación
de JWT cambia a Supabase igual que en Fase 3.

```bash
firebase deploy --only functions:voiceQuery
```

---

### Fase 6 — Modo Crisis (3 endpoints)

**Skill de referencia**: `skills/paso-modo-crisis/SKILL.md`

Archivo: `backend/functions/src/crisis/crisis.js`

Endpoints:
- `POST /crisis/start` — inserta sesión en `crisis_sessions`, busca punto seguro, notifica contactos
- `PUT /crisis/:id/update` — actualiza `current_lat/lng/location` (Supabase Realtime emite el cambio)
- `DELETE /crisis/:id/resolve` — actualiza `status = 'resolved'`

**Real-time en el cliente** (reemplaza `onValue()` de Firebase):
```javascript
const channel = supabase.channel('crisis-' + sessionId)
  .on('postgres_changes', {
    event: 'UPDATE',
    schema: 'public',
    table: 'crisis_sessions',
    filter: `id=eq.${sessionId}`
  }, (payload) => updateMarkerOnMap(payload.new))
  .subscribe();
```

```bash
firebase deploy --only functions:crisisStart,crisisUpdate,crisisResolve
```

---

## Cómo funciona el HTML de prueba

El `backend/public/index.html` tiene una pestaña por feature. No usa frameworks — solo:
- **Supabase JS SDK v2** para Auth, Storage y Realtime
- `fetch()` para llamar a las Cloud Functions
- Google Maps JS API para renderizar el mapa y las rutas

El cliente nunca tiene credenciales de servidor (Gemini, BigQuery, Maps Routes API, `SUPABASE_SERVICE_KEY`).
Solo tiene `SUPABASE_ANON_KEY` y la Maps JS API key (restringida por dominio).

---

## Skills disponibles por feature

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

### `clients.js`
Inicializa el cliente Supabase (service role) una sola vez y lo exporta.
Todos los módulos importan de aquí — nunca crean su propio cliente.

```js
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

module.exports = { supabase };
```

### `nodeUtils.js`
Funciones reutilizables sobre `accessibility_nodes`. PostGIS elimina la necesidad de
geohash y filtrado en memoria:

- `findNodesInBoundingBox(bounds)` — `ST_Within(location, ST_MakeEnvelope(...))`
- `findNearestNode(lat, lng, radiusMeters)` — `ST_DWithin(location, ST_Point(lng,lat)::geography, r)`
- `upsertNode(nodeData)` — `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`

### `constants.js`
Valores de negocio centralizados:
- `severityToScore(severity)` → `10 - severity`
- `THRESHOLDS = { wheelchair: 6, elderly: 4, standard: 3 }`
- `RUTA_VIVA_CACHE_TTL_MS = 30 * 60 * 1000`
- `REPORT_NEARBY_RADIUS_METERS = 30`
- `RUTA_VIVA_HISTORICAL_WEIGHT = 0.7`, `RUTA_VIVA_RECENT_WEIGHT = 0.3`

---

## Seguridad

### Row Level Security (RLS) en Supabase

Correr en el SQL Editor de Supabase junto con el schema:

```sql
-- Habilitar RLS en todas las tablas
ALTER TABLE public.accessibility_nodes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crisis_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles        ENABLE ROW LEVEL SECURITY;

-- accessibility_nodes: lectura pública, escritura solo service role
CREATE POLICY "nodes_read_public"  ON public.accessibility_nodes FOR SELECT USING (true);
CREATE POLICY "nodes_write_admin"  ON public.accessibility_nodes FOR ALL
  USING (auth.role() = 'service_role');

-- reports: cada usuario lee/crea sus propios reportes
CREATE POLICY "reports_own_read"   ON public.reports FOR SELECT
  USING (auth.uid()::text = user_id);
CREATE POLICY "reports_own_insert" ON public.reports FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

-- crisis_sessions: el dueño lee, solo service role escribe
CREATE POLICY "crisis_own_read"    ON public.crisis_sessions FOR SELECT
  USING (auth.uid()::text = user_id);
CREATE POLICY "crisis_admin_write" ON public.crisis_sessions FOR ALL
  USING (auth.role() = 'service_role');

-- user_profiles: cada usuario lee y escribe su propio perfil
CREATE POLICY "profile_own"        ON public.user_profiles FOR ALL
  USING (auth.uid()::text = uid);
```

---

### Storage policies en Supabase

En Supabase Dashboard → Storage → Policies del bucket `reports`:

```sql
-- Solo el dueño puede subir a su carpeta
CREATE POLICY "reports_upload_own" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'reports'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND octet_length(decode(encode(storage.filename(name),'escape'),'escape')) < 10485760);

-- Cualquier usuario autenticado puede leer fotos
CREATE POLICY "reports_read_auth"  ON storage.objects FOR SELECT
  USING (bucket_id = 'reports' AND auth.role() = 'authenticated');
```

---

### Rate limiting en `/reports/submit`

Contar reportes del usuario en la última hora directamente en Supabase:

```js
// En report.js — antes de llamar geminiVision()
const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
const { count } = await supabase
  .from('reports')
  .select('*', { count: 'exact', head: true })
  .eq('user_id', uid)
  .gte('created_at', oneHourAgo);

if (count >= 5) {
  return res.status(429).json({ error: 'Límite de reportes por hora alcanzado' });
}
```

---

### Validación de inputs

**`routing.js`** — coordenadas dentro del bounding box de Tijuana:
```js
const TJ_BOUNDS = { latMin: 32.4, latMax: 32.7, lngMin: -117.2, lngMax: -116.8 };
function isValidCoord(lat, lng) {
  return lat >= TJ_BOUNDS.latMin && lat <= TJ_BOUNDS.latMax
      && lng >= TJ_BOUNDS.lngMin && lng <= TJ_BOUNDS.lngMax;
}
```

**`report.js`** — la `photoUrl` debe pertenecer al bucket de Supabase del proyecto:
```js
const STORAGE_PREFIX = `${process.env.SUPABASE_URL}/storage/v1/object/public/reports/`;
if (!photoUrl.startsWith(STORAGE_PREFIX)) {
  return res.status(400).json({ error: 'photoUrl no pertenece al bucket autorizado' });
}
```

**`auth.js`** — verificar JWT de Supabase en cada endpoint:
```js
const { data: { user }, error } = await supabase.auth.getUser(token);
if (error || !user) return res.status(401).json({ error: 'Unauthorized' });
const uid = user.id;
```

**`crisis.js`** — verificar ownership antes de actualizar o resolver:
```js
const { data: session } = await supabase
  .from('crisis_sessions')
  .select('user_id')
  .eq('id', sessionId)
  .single();
if (!session || session.user_id !== uid) {
  return res.status(403).json({ error: 'Sesión no encontrada o acceso denegado' });
}
```

---

### Checklist de seguridad antes de demo/deploy

- [ ] RLS habilitado en todas las tablas (verificar en Supabase → Authentication → Policies)
- [ ] Storage policies aplicadas en bucket `reports`
- [ ] Supabase Realtime activo en tabla `crisis_sessions`
- [ ] `SUPABASE_SERVICE_KEY` y `.env` fuera del repo (`git status`)
- [ ] `SUPABASE_ANON_KEY` en el frontend — confirmar que NO es `service_role`
- [ ] Maps JS API key restringida por dominio en Google Cloud Console
- [ ] Gemini API key sin restricciones de IP solo en desarrollo
- [ ] Rate limiting activo en `/reports/submit`
- [ ] Validación de coordenadas activa en `/routing/accessible`

---

## Notas generales

- **CORS**: siempre aplicar `cors({ origin: true })` en todas las Cloud Functions
- **Fire and forget**: inserciones en `accessibility_reports` y `civic_tickets` no bloquean la respuesta al cliente
- **Foto en Storage primero**: el cliente sube la foto a Supabase Storage y envía solo la URL
- **Score vs Severity**: `severityToScore()` en `shared/constants.js`. Score alto = más accesible.
- **PostGIS vs geohash**: no usar `ngeohash`. Toda búsqueda geoespacial usa `ST_DWithin` / `ST_Within`
- **Timezone**: el cliente envía ISO 8601 con offset explícito (`2026-05-28T10:00:00-07:00`)
- **`conversation.js` llama `routing.js` por import directo**, no por HTTP
- **Auth**: el cliente llama `supabase.auth.signInAnonymously()` al cargar; adjunta el JWT en
  cada request como `Authorization: Bearer <token>`. Las Cloud Functions verifican con
  `supabase.auth.getUser(token)`. Sin uid válido → 401.
- **Ticket ID atómico**: `SELECT nextval('ticket_seq')` en Supabase. PostgreSQL garantiza
  atomicidad sin necesidad de transacciones manuales.
- **Supabase Realtime**: habilitar en Supabase Dashboard → Database → Replication →
  activar `crisis_sessions` para que los cambios se emitan al cliente en tiempo real.
