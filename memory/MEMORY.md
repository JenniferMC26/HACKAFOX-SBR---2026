# Memoria del proyecto — Paso (Hackathon 2026)

> Índice ligero. Leer antes de empezar cualquier sesión.

## Archivos clave

- [Estado del proyecto](project-status.md) — qué está hecho, qué falta, prioridades actuales
- Schema principal: `supabase-schema.sql` (raíz del repo) — incluye sección 7 (patch browser-direct)
- Frontend demo: `backend/public/index.html` — SPA, Supabase UMD, sin emulador
- Config pública: `backend/public/config.js` — claves inline, nunca SERVICE_KEY

## Contexto rápido

**Proyecto**: Ruteo accesible Tijuana — wheelchair, elderly, cane, stroller, none.
**Stack**: Supabase PostgreSQL+PostGIS / Firebase Cloud Functions Node.js 20 / Google Maps / Gemini Vision.
**Estado**: Código completo. Falta aplicar schema patch en Supabase y correr seed.
**Foco actual**: Base de datos — aplicar migraciones, verificar RPCs, seed data.

## Preferencias del usuario observadas

- Español en todo (código, comentarios, UI)
- Respuestas cortas y directas
- Edits quirúrgicos, no reescrituras completas salvo que sea necesario
- Siempre guardar archivos finales en la carpeta del workspace (no solo mostrar código)
- Quiere ver las cosas funcionar, no solo el código — prioriza ejecutabilidad

## Credenciales (solo referencia — nunca en frontend)

- Supabase URL: https://xagroifcepcxhzeserda.supabase.co
- SUPABASE_SERVICE_KEY: en backend/.env — NUNCA en frontend
- SUPABASE_ANON_KEY: sb_publishable_gCb6wyXQ8Dcn7_J-CuAPiQ_M4y6RDkR (pública, ok en frontend)
- GOOGLE_MAPS_API_KEY / GEMINI_API_KEY: misma clave en .env — posiblemente placeholder, necesita verificación
