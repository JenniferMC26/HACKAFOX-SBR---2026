-- PASO 1: Verificar si la función existe
-- (corre esto primero, debe devolver 1 fila)
SELECT proname, pronargs, proargnames
FROM pg_proc
WHERE proname = 'submit_report_background'
  AND pronamespace = 'public'::regnamespace;

-- ─────────────────────────────────────────────────────────────────────────────
-- Si la query de arriba devuelve 0 filas → la función no se creó.
-- Corre el bloque de abajo en una nueva query en el SQL Editor.
-- ─────────────────────────────────────────────────────────────────────────────

-- PASO 2: Drop + recrear limpio (evita conflictos de overload)
DROP FUNCTION IF EXISTS public.submit_report_background(
  TEXT, TEXT, FLOAT8, FLOAT8, TEXT, INT, INT, INT,
  TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, INT
);

CREATE OR REPLACE FUNCTION public.submit_report_background(
  p_report_id          TEXT,
  p_uid                TEXT,
  p_lat                FLOAT8,
  p_lng                FLOAT8,
  p_barrier_type       TEXT,
  p_severity           INT,
  p_hour               INT,
  p_dow                INT,
  p_weather            TEXT DEFAULT NULL,
  p_reported_at        TIMESTAMPTZ DEFAULT NOW(),
  p_ticket_id          TEXT DEFAULT NULL,
  p_photo_url          TEXT DEFAULT NULL,
  p_gemini_description TEXT DEFAULT NULL,
  p_affected_users     INT DEFAULT 0
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.accessibility_reports (
    report_id, user_id, lat, lng, barrier_type, severity,
    hour_of_day, day_of_week, weather_condition, reported_at
  ) VALUES (
    p_report_id, p_uid, p_lat, p_lng, p_barrier_type, p_severity,
    p_hour, p_dow, p_weather, p_reported_at
  );

  IF p_ticket_id IS NOT NULL THEN
    INSERT INTO public.civic_tickets (
      ticket_id, report_id, lat, lng, barrier_type, severity,
      photo_url, gemini_description, affected_users_estimate, status
    ) VALUES (
      p_ticket_id, p_report_id, p_lat, p_lng, p_barrier_type, p_severity,
      p_photo_url, p_gemini_description, p_affected_users, 'open'
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_report_background TO authenticated;

-- Reload via SELECT (más confiable que NOTIFY en algunos setups de Supabase)
SELECT pg_notify('pgrst', 'reload schema');
