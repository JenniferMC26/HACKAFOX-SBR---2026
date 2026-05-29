# Paso — Plan de Implementación

Plataforma de ruteo accesible en tiempo real para Tijuana. **Arquitectura
Supabase-only**: una sola página HTML estática (la test console actual, y el
futuro Flutter) habla directo con Supabase para auth, datos, storage y
realtime. Sin backend propio.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Base de datos | Supabase PostgreSQL + PostGIS |
| Autenticación | Supabase Auth (email/password y anónimo) |
| Almacenamiento de fotos | Supabase Storage |
| Realtime (Modo Crisis) | Supabase Realtime (postgres_changes) |
| Análisis de imágenes | Gemini Vision API (`gemini-2.5-flash`) — llamada directa desde el cliente |
| Ruteo y mapas | Google Maps Routes API + Maps JS API — llamada directa desde el cliente |
| Frontend de prueba | HTML plano + Supabase JS SDK v2 + Google Maps JS API |
| Servidor estático local | nginx vía Docker Compose |

---

## Estructura

```
Paso/
├── CLAUDE.md                       # Este archivo
├── supabase-schema.sql             # DDL completo de tablas + RLS
├── skills/                         # Skills de referencia por feature
│   ├── paso-seed-data/
│   ├── paso-routing-engine/
│   ├── paso-puente-ciudadano/
│   ├── paso-ruta-viva/
│   ├── paso-navegador-voz/
│   └── paso-modo-crisis/
└── backend/                        # mal nombrado — todo es cliente y seeds
    ├── public/
    │   ├── index.html              # Test console — pestañas por feature
    │   ├── config.example.js       # Plantilla — copiar a config.js
    │   └── config.js               # gitignored — define window.PASO_CONFIG
    ├── seed/
    │   ├── supabase-seed.js        # Inserta nodos estimados + patrones temporales
    │   ├── users-seed.js           # Inserta usuarios de prueba en Supabase Auth
    │   ├── estimated-nodes.json    # 14 nodos estimados
    │   └── field-captures.json     # Nodos a verificar en campo
    ├── docker-compose.yml          # web (nginx :5000) + seed (Node.js)
    ├── Dockerfile                  # Imagen Node 22 para el seed runner
    ├── package.json                # Dep: @supabase/supabase-js
    └── .env                        # gitignored — SUPABASE_SERVICE_KEY etc.
```

---

## Variables de entorno

### `backend/public/config.js` — keys del browser

Copiar `config.example.js` a `config.js` (gitignored) y rellenar:

```js
window.PASO_CONFIG = {
  SUPABASE_URL:        'https://<proyecto>.supabase.co',
  SUPABASE_ANON_KEY:   '<anon-key>',         // protegida por RLS
  GOOGLE_MAPS_API_KEY: '<maps-js-key>',      // restringir por dominio en GCP
  GEMINI_API_KEY:      '<gemini-key>',       // ⚠ inline en browser — restringir por referer en GCP
};
```

### `backend/.env` — keys del servidor (solo para seed scripts)

```bash
SUPABASE_URL=https://<proyecto>.supabase.co
SUPABASE_SERVICE_KEY=...     # service_role — admin total
SUPABASE_ANON_KEY=...
GEMINI_API_KEY=...           # opcional, si los seeds llaman Gemini
GOOGLE_MAPS_API_KEY=...
```

⚠ `SUPABASE_SERVICE_KEY` es admin total. Nunca en el browser, nunca commitear.

---

## Esquema Supabase

Correr `supabase-schema.sql` desde el SQL Editor de Supabase. Cubre:

- `accessibility_nodes` — nodos urbanos con PostGIS
- `reports` — reportes ciudadanos
- `accessibility_reports` — historial (analítica)
- `temporal_patterns` — para Ruta Viva
- `civic_tickets` — tickets municipales (severity ≥ 7)
- `crisis_sessions` — sesiones de emergencia con Realtime
- `user_profiles` — perfil de movilidad y condición
- `notifications` — alertas a contactos
- Función SQL `ruta_viva_history(...)` y secuencia `ticket_seq`
- Row Level Security en todas las tablas

---

## Entorno de desarrollo

### Prerequisitos (una vez por máquina)

1. Instalar **Docker Desktop** (activar WSL2 en Windows)
2. Crear proyecto en **supabase.com**:
   - SQL Editor → pegar y correr `supabase-schema.sql`
   - Authentication → Providers → activar "Email" y opcionalmente "Anonymous"
   - Storage → crear bucket `reports` (público: false)
   - Database → Replication → activar tabla `crisis_sessions`
3. Crear `backend/public/config.js` desde `config.example.js`
4. Crear `backend/.env` desde `backend/.env.example` (si se usa seed)

### Comandos

```bash
cd backend/

# Levantar la test console (nginx en :5000)
docker compose up -d

# Apagar
docker compose down

# Construir imagen del seed runner (primera vez o tras tocar package.json)
docker compose build seed

# Correr scripts de seed
docker compose run --rm seed node seed/supabase-seed.js
docker compose run --rm seed node seed/users-seed.js
```

Abrir `http://localhost:5000`. Las claves vienen de `public/config.js`.

---

## Arquitectura del cliente (`public/index.html`)

Todo corre en un solo archivo HTML. No hay backend.

1. **Auth** — `supabase.auth.signInWithPassword({...})` / `signUp` / `signInAnonymously`
2. **Perfil** — `user_profiles` con upsert; los botones de movilidad guardan `mobility_type` y si eligen "Adulto mayor" muestran un select adicional para `condicion_adulto_mayor`
3. **Ruteo accesible** (`pane-ruta`) — llama Google Routes API → decodifica polyline → consulta `accessibility_nodes` con PostGIS bounding box → calcula score promedio + warnings → aplica umbral por perfil
4. **Reporte** (`pane-report`) — sube foto a Supabase Storage `reports/{uid}/`, llama Gemini Vision con base64 inline, upsert en `accessibility_nodes` (PostGIS nearest neighbor a 30m), insert en `reports` + `accessibility_reports`, si severity ≥ 7 genera ticket `PASO-YYYY-NNNN` en `civic_tickets`
5. **Ruta Viva** (`pane-viva`) — consulta `temporal_patterns` por (hora, día, radio 200m); fallback si data < 3; combina 70% histórico + 30% reportes recientes; cache 30 min en memoria
6. **Crisis** (`pane-crisis`) — insert en `crisis_sessions`, suscripción Realtime al canal `crisis-<id>` con filtro `postgres_changes`, updates de ubicación, resolución

---

## Seguridad

### Row Level Security

Aplicado en `supabase-schema.sql`:

- `accessibility_nodes` — lectura pública, escritura solo service_role
- `reports` — el dueño lee y escribe los suyos
- `crisis_sessions` — el dueño lee, service_role escribe
- `user_profiles` — el dueño lee y escribe el suyo
- `notifications` — el destinatario lee, service_role escribe

### Storage policies (bucket `reports`)

```sql
CREATE POLICY "reports_upload_own" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'reports'
    AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "reports_read_auth" ON storage.objects FOR SELECT
  USING (bucket_id = 'reports' AND auth.role() = 'authenticated');
```

### Claves expuestas en `config.js`

| Clave | Riesgo | Mitigación |
|-------|--------|------------|
| `SUPABASE_ANON_KEY` | Bajo — RLS protege | Mantener policies actualizadas |
| `GOOGLE_MAPS_API_KEY` | Medio — abuso de cuota | Restricción por dominio en GCP Console |
| `GEMINI_API_KEY` | Medio — abuso de cuota | Restricción por HTTP referer en GCP Console; idealmente mover a Supabase Edge Function |

### Validaciones en el cliente

- Bounding box Tijuana: `lat ∈ [32.4, 32.7]`, `lng ∈ [-117.2, -116.8]`
- Rate limit reportes: contar `reports` del uid en última hora con `count`; bloquear ≥ 5
- Verificar ownership antes de update/resolve de `crisis_sessions`

---

## Skills disponibles

| Feature | Skill |
|---------|-------|
| Seed data | `skills/paso-seed-data/SKILL.md` |
| Motor de ruteo | `skills/paso-routing-engine/SKILL.md` |
| Puente Ciudadano | `skills/paso-puente-ciudadano/SKILL.md` |
| Ruta Viva | `skills/paso-ruta-viva/SKILL.md` |
| Navegador Sin Pantalla | `skills/paso-navegador-voz/SKILL.md` |
| Modo Crisis | `skills/paso-modo-crisis/SKILL.md` |

Las skills se redactaron asumiendo Cloud Functions — la lógica es equivalente,
pero ahora corre en `index.html` en vez de en `backend/functions/`. Revisar la
implementación en `pane-*` correspondiente.

---

## Notas

- **PostGIS, no geohash**: toda búsqueda geoespacial usa `ST_DWithin` / `ST_Within`
- **Timezone**: el cliente formatea `hour_of_day` y `day_of_week` con `Intl.DateTimeFormat({ timeZone: 'America/Tijuana' })`
- **Ticket ID atómico**: `SELECT nextval('ticket_seq')` desde un RPC de Supabase
- **Realtime**: habilitar `crisis_sessions` en Supabase Dashboard → Database → Replication
