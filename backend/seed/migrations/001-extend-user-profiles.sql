-- ============================================================================
-- Migración 001 — Extender user_profiles con datos de usuario completos
--
-- Ejecutar en Supabase Dashboard → SQL Editor → New query.
-- Es idempotente: usa IF NOT EXISTS / DO $$ para no fallar en re-ejecuciones.
-- ============================================================================

-- 1. Agregar columnas nuevas (IF NOT EXISTS evita error si ya existen)
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS nombre               TEXT,
  ADD COLUMN IF NOT EXISTS telefono             TEXT,
  ADD COLUMN IF NOT EXISTS tipo_discapacidad    TEXT,
  ADD COLUMN IF NOT EXISTS condicion_adulto_mayor TEXT,
  ADD COLUMN IF NOT EXISTS telefono_emergencia  TEXT;

-- 2. CHECK en tipo_discapacidad
--    (PostgreSQL no tiene ADD CONSTRAINT IF NOT EXISTS; usamos el bloque DO)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profiles_tipo_discapacidad_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_tipo_discapacidad_check
      CHECK (tipo_discapacidad IS NULL OR tipo_discapacidad = ANY (ARRAY[
        'motriz_silla',    -- silla de ruedas
        'motriz_baston',   -- bastón / andadera
        'adulto_mayor',    -- adulto mayor (abre campo secundario)
        'visual',          -- discapacidad visual
        'auditiva',        -- discapacidad auditiva
        'cognitiva',       -- discapacidad cognitiva / intelectual
        'temporal',        -- lesión o condición temporal
        'ninguna',         -- sin discapacidad
        'otra'
      ]));
  END IF;
END $$;

-- 3. CHECK en condicion_adulto_mayor
--    Solo tiene sentido cuando tipo_discapacidad = 'adulto_mayor'.
--    A nivel DB permitimos cualquier valor para flexibilidad; la validación
--    fuerte la hacemos en el frontend (ver lista de valores abajo).
--    Valores esperados:
--      'artritis', 'osteoporosis', 'vision_reducida', 'audicion_reducida',
--      'diabetes', 'equilibrio', 'demencia_leve', 'otra'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profiles_condicion_am_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_condicion_am_check
      CHECK (condicion_adulto_mayor IS NULL OR condicion_adulto_mayor = ANY (ARRAY[
        'artritis',
        'osteoporosis',
        'vision_reducida',
        'audicion_reducida',
        'diabetes',
        'equilibrio',
        'demencia_leve',
        'otra'
      ]));
  END IF;
END $$;

-- 4. Restricción de negocio: condicion_adulto_mayor solo aplica para adulto_mayor
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_profiles_condicion_am_solo_adulto'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_condicion_am_solo_adulto
      CHECK (
        condicion_adulto_mayor IS NULL
        OR tipo_discapacidad = 'adulto_mayor'
      );
  END IF;
END $$;

-- 5. Índice útil para estadísticas por tipo de discapacidad
CREATE INDEX IF NOT EXISTS idx_profiles_tipo_discapacidad
  ON public.user_profiles (tipo_discapacidad);

-- ── Verificación ────────────────────────────────────────────────────────────
-- Ejecutar para confirmar que las columnas quedaron:
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'user_profiles'
-- ORDER BY ordinal_position;
