-- ============================================================================
-- Migracion 004 — Adaptacion para autenticacion por telefono
--
-- Supabase Phone Auth usa auth.users.phone como identificador.
-- El uid sigue siendo auth.uid() (UUID), pero ahora el usuario se registra
-- con telefono + password. Esta migracion:
--   1. Asegura que user_profiles.telefono exista (ya existe de migracion 001)
--   2. Actualiza las RLS policies para que funcionen con phone auth
--      (auth.uid()::text sigue funcionando igual — no cambia nada)
--   3. Agrega indice en telefono para busquedas rapidas
-- ============================================================================

-- 1. Indice para busqueda por telefono (ej. buscar contacto de emergencia)
CREATE INDEX IF NOT EXISTS idx_profiles_telefono
  ON public.user_profiles (telefono);

-- 2. Notificar a PostgREST para que recargue el schema
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- NOTA: No se necesitan cambios en RLS. Supabase Phone Auth sigue usando
-- auth.uid() como identificador del usuario, que es lo que ya usan todas
-- las policies. El campo 'phone' es solo el metodo de login, no el PK.
--
-- Para activar Phone Auth en Supabase Dashboard:
-- 1. Authentication → Providers → Phone → Enable
-- 2. Configurar proveedor SMS (Twilio, MessageBird, Vonage)
-- 3. O deshabilitar "Confirm phone" para desarrollo sin SMS
-- ============================================================================
