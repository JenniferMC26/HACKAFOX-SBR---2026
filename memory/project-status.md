# Estado del proyecto — Paso

## Qué es
Plataforma de ruteo accesible para Tijuana. Silla de ruedas, adulto mayor, bastón, carriola.
Hackathon 2026. Backend: Firebase Cloud Functions (Node.js 20) + Supabase PostgreSQL/PostGIS.
Frontend demo: HTML SPA (index.html). Frontend final: Flutter (fuera de alcance ahora).

## Lo que está hecho

### Base de datos (supabase-schema.sql — raíz del repo)
- 8 tablas: accessibility_nodes, reports, crisis_sessions, user_profiles, notifications,
  accessibility_reports, temporal_patterns, civic_tickets
- Secuencia ticket_seq para IDs tipo PASO-2026-0001
- 6 RPCs PostGIS: nodes_in_bbox, nearest_node, upsert_node_near, recent_reports_near,
  next_ticket_id, ruta_viva_history
- **Sección 7 (patch browser-direct)**: SECURITY DEFINER en upsert_node_near / next_ticket_id /
  recent_reports_near, nueva función submit_report_background, políticas crisis para
  authenticated, GRANT EXECUTE en todas las RPCs
- RLS habilitado en todas las tablas
- Storage policies en bucket "reports"
- Realtime habilitado en crisis_sessions y notifications

### Backend Cloud Functions (backend/functions/)
- index.js: 8 endpoints registrados (config, routingAccessible, reportSubmit, rutaVivaScore,
  voiceQuery, crisisStart, crisisUpdate, crisisResolve)
- routing.js: motor de ruteo, bug latLng corregido ({ latitude, longitude } para Routes API v2)
- report.js: timezone fix (UTC→America/Tijuana para hour_of_day/day_of_week)
- geminiVision.js: wrapper Gemini Vision
- prediction.js: Ruta Viva con blend 70% histórico / 30% reciente
- crisis.js: Modo Crisis con Realtime
- conversation.js: voz → llama routing.js directo

### Frontend (backend/public/)
- index.html: SPA completa — login/registro/anónimo, perfil de movilidad, mapa Google Maps,
  4 pestañas (Ruta, Reportar, Ruta Viva, Crisis). Supabase UMD (no ES module).
  Invitado = pase directo sin auth. Config inline (sin fetch al emulador).
- config.js: claves públicas (SUPABASE_ANON_KEY, GOOGLE_MAPS_API_KEY, GEMINI_API_KEY)
- supabase-config.js: importa de config.js, no depende del emulador

### Seed (backend/seed/)
- supabase-seed.js: 14 nodos + 4032 filas temporal_patterns (6 POIs × 24h × 7d × 4 reps)
- users-seed.js: 3 usuarios de prueba (wheelchair, elderly, contact)
- estimated-nodes.json: coordenadas de los 14 nodos
- supabase-schema.sql duplicado en raíz del repo (es el mismo archivo)

## Lo que FALTA / está pendiente

### Base de datos (prioridad actual)
- Aplicar sección 7 del schema en Supabase SQL Editor (SECURITY DEFINER patch)
- Correr el seed: `docker compose run --rm seed node seed/supabase-seed.js`
- Verificar que las RPCs responden desde el browser (sin error 403/RLS)
- Confirmar que temporal_patterns tiene datos (Ruta Viva necesita ≥3 puntos por slot)
- Confirmar que anonymous sign-in está habilitado en Supabase Auth → Providers
- Confirmar bucket "reports" creado en Supabase Storage (private)
- Confirmar Realtime activo en crisis_sessions

### Frontend
- Las API keys (GEMINI, GOOGLE_MAPS) son el mismo valor en .env — probablemente placeholder;
  necesitan claves reales de Google AI Studio y Google Cloud Console
- Probar flujo completo de reporte: foto → Gemini → Storage → Supabase

### Backend
- No hay tests automatizados
- Crisis mode no notifica contactos todavía (tabla notifications existe pero sin lógica de envío)
