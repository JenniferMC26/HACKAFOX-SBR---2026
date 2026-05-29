-- ============================================================================
-- Migration 005: Fix reporte — tres problemas corregidos
--
-- Fix 1: "attempted to lock invisible tuple" (XX000) en upsert_node_near
--   SELECT ... LIMIT 1 FOR UPDATE con PostGIS falla bajo concurrencia.
--   Solución: subquery anidada — inner SELECT por snapshot, outer FOR UPDATE por PK.
--
-- Fix 2: submit_report_background no encontrada (PGRST202 / 404)
--   La función no está en el schema cache de PostgREST. Se re-crea aquí
--   y se añaden los GRANTs necesarios. Al final se fuerza reload del cache.
--
-- Fix 3: Política UPDATE faltante en `reports`
--   Sin ella el update de ticket_id falla cuando severity >= 7.
-- ============================================================================

-- Fix 1: Reemplazar upsert_node_near con locking seguro
CREATE OR REPLACE FUNCTION public.upsert_node_near(
  p_lat             FLOAT8,
  p_lng             FLOAT8,
  p_radius_m        FLOAT8,
  p_type            TEXT,
  p_accessible      BOOLEAN,
  p_score           INT,
  p_barrier_type    TEXT,
  p_photo_url       TEXT,
  p_gemini_analysis JSONB,
  p_source          TEXT DEFAULT 'field_verified'
) RETURNS public.accessibility_nodes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  existing_id TEXT;
  result      public.accessibility_nodes;
BEGIN
  -- Identificar el nodo más cercano via subquery (snapshot read estable),
  -- luego lockear por PK para evitar "attempted to lock invisible tuple"
  -- que ocurre con LIMIT + FOR UPDATE en scans geoespaciales concurrentes.
  SELECT id INTO existing_id
  FROM public.accessibility_nodes
  WHERE id = (
    SELECT id
    FROM public.accessibility_nodes
    WHERE ST_DWithin(
      location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_m
    )
    ORDER BY location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT 1
  )
  FOR UPDATE;

  IF existing_id IS NOT NULL THEN
    UPDATE public.accessibility_nodes
    SET
      accessible      = p_accessible,
      score           = p_score,
      source          = p_source,
      barrier_type    = p_barrier_type,
      photo_url       = COALESCE(p_photo_url, photo_url),
      gemini_analysis = p_gemini_analysis,
      last_reported   = NOW(),
      report_count    = report_count + 1,
      updated_at      = NOW()
    WHERE id = existing_id
    RETURNING * INTO result;
  ELSE
    INSERT INTO public.accessibility_nodes
      (lat, lng, type, accessible, score, source, barrier_type, photo_url,
       gemini_analysis, last_reported, report_count)
    VALUES
      (p_lat, p_lng, COALESCE(p_type, 'sidewalk'), p_accessible, p_score,
       p_source, p_barrier_type, p_photo_url, p_gemini_analysis, NOW(), 1)
    RETURNING * INTO result;
  END IF;

  RETURN result;
END;
$$;

-- Fix 2: Re-crear submit_report_background (PGRST202 — función no encontrada)
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

-- GRANTs para que el cliente autenticado pueda llamar las RPCs
GRANT EXECUTE ON FUNCTION public.upsert_node_near       TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_ticket_id         TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_report_background TO authenticated;

-- Fix 3: Política UPDATE para que usuarios autenticados puedan
-- escribir ticket_id en sus propios reportes (necesario cuando severity >= 7).
DROP POLICY IF EXISTS "reports_own_update" ON public.reports;
CREATE POLICY "reports_own_update" ON public.reports
  FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

-- Forzar reload del schema cache de PostgREST para que detecte las funciones.
NOTIFY pgrst, 'reload schema';
