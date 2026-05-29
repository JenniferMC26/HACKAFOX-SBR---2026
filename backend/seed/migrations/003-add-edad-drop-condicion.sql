-- 003: Cambia el modelo de adulto mayor.
--
-- El HTML ya no manda 'condicion_adulto_mayor'. Reemplazo con un campo
-- numérico 'edad' que se rellena en el formulario.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS edad INT CHECK (edad IS NULL OR (edad >= 1 AND edad <= 120));

-- Quitar la restricción vieja que ataba condicion_adulto_mayor a tipo_discapacidad
-- (por si existe en el proyecto y bloquea inserts).
ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_condicion_am_solo_adulto;

-- Forzar a PostgREST a recargar el cache de schema — sin esto el cliente
-- sigue viendo "column not found" hasta el siguiente restart de Supabase.
NOTIFY pgrst, 'reload schema';
