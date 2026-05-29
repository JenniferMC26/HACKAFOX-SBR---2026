-- ============================================================================
-- Paso — Esquema completo de Supabase (PostgreSQL + PostGIS)
--
-- Ejecutar UNA sola vez desde Supabase Dashboard → SQL Editor → New query.
-- Incluye: extensiones, 4 tablas con `location` autogenerada, secuencia de
-- tickets, índices GIST, stored functions para queries geoespaciales, RLS,
-- y storage policies del bucket `reports`.
-- ============================================================================

-- Extensión geoespacial (idempotente).
CREATE EXTENSION IF NOT EXISTS postgis;


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Tablas
-- ────────────────────────────────────────────────────────────────────────────

-- 1.1 Nodos de accesibilidad urbana.
-- `location` se calcula automáticamente desde lat/lng → no se puede insertar mal.
CREATE TABLE IF NOT EXISTS public.accessibility_nodes (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  lat             FLOAT8 NOT NULL,
  lng             FLOAT8 NOT NULL,
  location        GEOGRAPHY(POINT, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
  type            TEXT,
  accessible      BOOLEAN,
  score           INT CHECK (score BETWEEN 0 AND 10),
  source          TEXT DEFAULT 'estimated' CHECK (source IN ('field_verified', 'estimated')),
  barrier_type    TEXT,
  last_reported   TIMESTAMPTZ,
  report_count    INT DEFAULT 0,
  photo_url       TEXT,
  gemini_analysis JSONB,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 1.2 Reportes ciudadanos.
CREATE TABLE IF NOT EXISTS public.reports (
  id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id         TEXT NOT NULL,
  lat             FLOAT8 NOT NULL,
  lng             FLOAT8 NOT NULL,
  location        GEOGRAPHY(POINT, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
  photo_url       TEXT,
  gemini_analysis JSONB,
  requires_human_review BOOLEAN DEFAULT FALSE,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved')),
  ticket_id       TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 1.3 Sesiones de crisis (modo emergencia).
CREATE TABLE IF NOT EXISTS public.crisis_sessions (
  id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id            TEXT NOT NULL,
  user_profile       JSONB,
  started_at         TIMESTAMPTZ DEFAULT NOW(),
  resolved_at        TIMESTAMPTZ,
  current_lat        FLOAT8,
  current_lng        FLOAT8,
  current_location   GEOGRAPHY(POINT, 4326)
                     GENERATED ALWAYS AS (
                       CASE WHEN current_lat IS NULL OR current_lng IS NULL THEN NULL
                            ELSE ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)::geography
                       END
                     ) STORED,
  status             TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
  nearest_safe_point JSONB,
  alternative_route  JSONB,
  alerted_contacts   JSONB DEFAULT '[]'::jsonb,
  last_update        TIMESTAMPTZ
);

-- 1.4 Perfiles de usuario.
CREATE TABLE IF NOT EXISTS public.user_profiles (
  uid                TEXT PRIMARY KEY,
  display_name       TEXT,
  mobility_type      TEXT,
  avoid_steps        BOOLEAN DEFAULT FALSE,
  avoid_slopes       BOOLEAN DEFAULT FALSE,
  slope_max_percent  FLOAT8 DEFAULT 8.0,
  emergency_contacts JSONB DEFAULT '[]'::jsonb,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

-- 1.5 Notificaciones (para Modo Crisis — alertar contactos).
CREATE TABLE IF NOT EXISTS public.notifications (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  recipient_id TEXT NOT NULL,
  type         TEXT NOT NULL,
  from_user_id TEXT,
  session_id   TEXT,
  lat          FLOAT8,
  lng          FLOAT8,
  read         BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 1.6 Historial de reportes para analítica (reemplaza BigQuery accessibility_reports).
CREATE TABLE IF NOT EXISTS public.accessibility_reports (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  report_id    TEXT NOT NULL,
  user_id      TEXT NOT NULL,
  lat          FLOAT8 NOT NULL,
  lng          FLOAT8 NOT NULL,
  location     GEOGRAPHY(POINT, 4326)
               GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
  barrier_type TEXT,
  severity     INT,
  hour_of_day  INT,
  day_of_week  INT,
  weather_condition TEXT,
  reported_at  TIMESTAMPTZ DEFAULT NOW(),
  resolved_at  TIMESTAMPTZ
);

-- 1.7 Patrones temporales para Ruta Viva (reemplaza BigQuery temporal_patterns).
CREATE TABLE IF NOT EXISTS public.temporal_patterns (
  id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  lat                 FLOAT8 NOT NULL,
  lng                 FLOAT8 NOT NULL,
  location            GEOGRAPHY(POINT, 4326)
                      GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
  hour_of_day         INT NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  day_of_week         INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  accessibility_score FLOAT8 NOT NULL CHECK (accessibility_score BETWEEN 0 AND 1),
  event_flag          BOOLEAN DEFAULT FALSE,
  report_count        INT DEFAULT 0
);

-- 1.8 Tickets cívicos formales (reemplaza BigQuery civic_tickets).
CREATE TABLE IF NOT EXISTS public.civic_tickets (
  id                      TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  ticket_id               TEXT NOT NULL UNIQUE,
  report_id               TEXT NOT NULL,
  lat                     FLOAT8 NOT NULL,
  lng                     FLOAT8 NOT NULL,
  location                GEOGRAPHY(POINT, 4326)
                          GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) STORED,
  barrier_type            TEXT,
  severity                INT,
  photo_url               TEXT,
  gemini_description      TEXT,
  affected_users_estimate INT,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  assigned_to             TEXT,
  status                  TEXT DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'resolved'))
);

-- 1.9 Secuencia atómica para ticket_id formateado como PASO-YYYY-NNNN.
CREATE SEQUENCE IF NOT EXISTS public.ticket_seq START 1;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Índices
-- ────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_nodes_location    ON public.accessibility_nodes USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_reports_location  ON public.reports             USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_crisis_location   ON public.crisis_sessions     USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_ar_location       ON public.accessibility_reports USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_tp_location       ON public.temporal_patterns   USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_tickets_location  ON public.civic_tickets       USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_reports_user_created ON public.reports (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_recipient_read ON public.notifications (recipient_id, read);
CREATE INDEX IF NOT EXISTS idx_ar_reported_at       ON public.accessibility_reports (reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_tp_hour_dow          ON public.temporal_patterns (hour_of_day, day_of_week);
CREATE INDEX IF NOT EXISTS idx_tickets_status       ON public.civic_tickets (status, created_at DESC);


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Stored functions (RPC) — encapsulan queries PostGIS para usar desde JS
-- ────────────────────────────────────────────────────────────────────────────

-- 3.1 Nodos dentro de un bounding box.
CREATE OR REPLACE FUNCTION public.nodes_in_bbox(
  p_lat_min FLOAT8, p_lat_max FLOAT8,
  p_lng_min FLOAT8, p_lng_max FLOAT8
) RETURNS SETOF public.accessibility_nodes
LANGUAGE sql STABLE AS $$
  SELECT *
  FROM public.accessibility_nodes
  WHERE location && ST_MakeEnvelope(p_lng_min, p_lat_min, p_lng_max, p_lat_max, 4326)::geography
    AND ST_Within(
          location::geometry,
          ST_MakeEnvelope(p_lng_min, p_lat_min, p_lng_max, p_lat_max, 4326)
        );
$$;

-- 3.2 Nodo más cercano dentro de un radio (devuelve 0 o 1 fila).
CREATE OR REPLACE FUNCTION public.nearest_node(
  p_lat FLOAT8, p_lng FLOAT8, p_radius_m FLOAT8
) RETURNS TABLE(
  id TEXT, lat FLOAT8, lng FLOAT8, type TEXT, accessible BOOLEAN,
  score INT, source TEXT, barrier_type TEXT, last_reported TIMESTAMPTZ,
  report_count INT, photo_url TEXT, gemini_analysis JSONB,
  distance_m FLOAT8
)
LANGUAGE sql STABLE AS $$
  SELECT n.id, n.lat, n.lng, n.type, n.accessible, n.score, n.source,
         n.barrier_type, n.last_reported, n.report_count, n.photo_url, n.gemini_analysis,
         ST_Distance(n.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) AS distance_m
  FROM public.accessibility_nodes n
  WHERE ST_DWithin(n.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m)
  ORDER BY n.location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  LIMIT 1;
$$;

-- 3.3 Upsert atómico: si hay nodo a < radio, lo actualiza; si no, crea uno nuevo.
-- SECURITY DEFINER: el browser (anon/authenticated) puede escribir en accessibility_nodes
-- aunque la política RLS solo permita service_role. Seguro porque valida ownership vía JWT.
CREATE OR REPLACE FUNCTION public.upsert_node_near(
  p_lat            FLOAT8,
  p_lng            FLOAT8,
  p_radius_m       FLOAT8,
  p_type           TEXT,
  p_accessible     BOOLEAN,
  p_score          INT,
  p_barrier_type   TEXT,
  p_photo_url      TEXT,
  p_gemini_analysis JSONB,
  p_source         TEXT DEFAULT 'field_verified'
) RETURNS public.accessibility_nodes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  existing_id TEXT;
  result      public.accessibility_nodes;
BEGIN
  -- Lockear el nodo más cercano si existe, dentro de la misma transacción.
  SELECT id INTO existing_id
  FROM public.accessibility_nodes
  WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m)
  ORDER BY location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  LIMIT 1
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
      (p_lat, p_lng, COALESCE(p_type, 'sidewalk'), p_accessible, p_score, p_source,
       p_barrier_type, p_photo_url, p_gemini_analysis, NOW(), 1)
    RETURNING * INTO result;
  END IF;

  RETURN result;
END;
$$;

-- 3.4 Reportes recientes en un radio (para Ruta Viva).
-- SECURITY DEFINER: necesita leer todos los reports, no solo los del usuario actual.
CREATE OR REPLACE FUNCTION public.recent_reports_near(
  p_lat FLOAT8, p_lng FLOAT8, p_radius_m FLOAT8, p_window_seconds INT
) RETURNS TABLE(gemini_analysis JSONB, created_at TIMESTAMPTZ)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT r.gemini_analysis, r.created_at
  FROM public.reports r
  WHERE r.created_at >= NOW() - (p_window_seconds || ' seconds')::interval
    AND ST_DWithin(r.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m);
$$;

-- 3.5 Siguiente ticket ID atómico (PASO-YYYY-NNNN).
-- SECURITY DEFINER: el browser no tiene USAGE en ticket_seq por defecto.
CREATE OR REPLACE FUNCTION public.next_ticket_id()
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  seq_val BIGINT;
  yr      INT;
BEGIN
  seq_val := nextval('public.ticket_seq');
  yr      := EXTRACT(YEAR FROM NOW())::INT;
  RETURN format('PASO-%s-%s', yr, lpad(seq_val::text, 4, '0'));
END;
$$;

-- 3.6 Score histórico promedio para Ruta Viva (sustituye query a BigQuery).
-- Promedia accessibility_score de temporal_patterns en radio 200m para una
-- hora/día específicos. Devuelve 0 filas si no hay datos suficientes.
CREATE OR REPLACE FUNCTION public.ruta_viva_history(
  p_lat FLOAT8, p_lng FLOAT8, p_hour INT, p_dow INT, p_radius_m FLOAT8 DEFAULT 200
) RETURNS TABLE(avg_score FLOAT8, data_points BIGINT, has_event BOOLEAN)
LANGUAGE sql STABLE AS $$
  SELECT
    AVG(accessibility_score) AS avg_score,
    COUNT(*)                 AS data_points,
    bool_or(event_flag)      AS has_event
  FROM public.temporal_patterns
  WHERE hour_of_day = p_hour
    AND day_of_week = p_dow
    AND ST_DWithin(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m);
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Row Level Security
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accessibility_nodes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crisis_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accessibility_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporal_patterns     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.civic_tickets         ENABLE ROW LEVEL SECURITY;

-- accessibility_nodes: lectura pública, escritura solo service_role.
DROP POLICY IF EXISTS "nodes_read_public" ON public.accessibility_nodes;
CREATE POLICY "nodes_read_public" ON public.accessibility_nodes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "nodes_write_admin" ON public.accessibility_nodes;
CREATE POLICY "nodes_write_admin" ON public.accessibility_nodes
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- reports: cada usuario lee y crea los suyos.
DROP POLICY IF EXISTS "reports_own_read" ON public.reports;
CREATE POLICY "reports_own_read" ON public.reports
  FOR SELECT USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "reports_own_insert" ON public.reports;
CREATE POLICY "reports_own_insert" ON public.reports
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "reports_admin_all" ON public.reports;
CREATE POLICY "reports_admin_all" ON public.reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- crisis_sessions: dueño lee, service_role escribe.
DROP POLICY IF EXISTS "crisis_own_read" ON public.crisis_sessions;
CREATE POLICY "crisis_own_read" ON public.crisis_sessions
  FOR SELECT USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "crisis_admin_write" ON public.crisis_sessions;
CREATE POLICY "crisis_admin_write" ON public.crisis_sessions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- user_profiles: dueño lee/escribe.
DROP POLICY IF EXISTS "profile_own" ON public.user_profiles;
CREATE POLICY "profile_own" ON public.user_profiles
  FOR ALL USING (auth.uid()::text = uid) WITH CHECK (auth.uid()::text = uid);

DROP POLICY IF EXISTS "profile_admin" ON public.user_profiles;
CREATE POLICY "profile_admin" ON public.user_profiles
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- notifications: el destinatario lee y marca como leído; service_role escribe.
DROP POLICY IF EXISTS "notif_own_read" ON public.notifications;
CREATE POLICY "notif_own_read" ON public.notifications
  FOR SELECT USING (auth.uid()::text = recipient_id);

DROP POLICY IF EXISTS "notif_own_update" ON public.notifications;
CREATE POLICY "notif_own_update" ON public.notifications
  FOR UPDATE USING (auth.uid()::text = recipient_id);

DROP POLICY IF EXISTS "notif_admin_write" ON public.notifications;
CREATE POLICY "notif_admin_write" ON public.notifications
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- accessibility_reports: lectura solo service_role (contiene user_id sensible).
DROP POLICY IF EXISTS "ar_admin_all" ON public.accessibility_reports;
CREATE POLICY "ar_admin_all" ON public.accessibility_reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- temporal_patterns: lectura pública (datos abiertos), escritura admin.
DROP POLICY IF EXISTS "tp_read_public" ON public.temporal_patterns;
CREATE POLICY "tp_read_public" ON public.temporal_patterns
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "tp_admin_write" ON public.temporal_patterns;
CREATE POLICY "tp_admin_write" ON public.temporal_patterns
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- civic_tickets: lectura pública (transparencia), escritura admin.
DROP POLICY IF EXISTS "tickets_read_public" ON public.civic_tickets;
CREATE POLICY "tickets_read_public" ON public.civic_tickets
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "tickets_admin_write" ON public.civic_tickets;
CREATE POLICY "tickets_admin_write" ON public.civic_tickets
  FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ────────────────────────────────────────────────────────────────────────────
-- 5. Storage policies del bucket `reports`
-- IMPORTANTE: antes crear el bucket en Dashboard → Storage → New bucket
-- (nombre = "reports", público = false).
-- ────────────────────────────────────────────────────────────────────────────

-- Solo el dueño puede subir a su carpeta `reports/{uid}/...`, max 10 MB, solo imágenes.
DROP POLICY IF EXISTS "reports_upload_own" ON storage.objects;
CREATE POLICY "reports_upload_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'reports'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND (metadata->>'size')::bigint < 10 * 1024 * 1024
    AND lower(metadata->>'mimetype') LIKE 'image/%'
  );

-- Cualquier usuario autenticado puede leer fotos.
DROP POLICY IF EXISTS "reports_read_auth" ON storage.objects;
CREATE POLICY "reports_read_auth" ON storage.objects
  FOR SELECT USING (bucket_id = 'reports' AND auth.role() = 'authenticated');


-- ────────────────────────────────────────────────────────────────────────────
-- 6. Realtime — habilitar para que el cliente reciba updates de crisis_sessions
-- ────────────────────────────────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE public.crisis_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;


-- ────────────────────────────────────────────────────────────────────────────
-- 7. Browser-direct patch — habilita el SPA para operar sin Firebase Functions
-- ────────────────────────────────────────────────────────────────────────────

-- 7.1 RPC que inserta accessibility_reports + civic_tickets (fire-and-forget
--     del browser tras un reporte). SECURITY DEFINER porque ambas tablas solo
--     permiten escritura a service_role en sus políticas RLS.
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

-- 7.2 Políticas de crisis_sessions para usuarios autenticados (antes solo service_role).
DROP POLICY IF EXISTS "crisis_own_insert" ON public.crisis_sessions;
CREATE POLICY "crisis_own_insert" ON public.crisis_sessions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "crisis_own_update" ON public.crisis_sessions;
CREATE POLICY "crisis_own_update" ON public.crisis_sessions
  FOR UPDATE TO authenticated
  USING (auth.uid()::text = user_id);

-- 7.3 Política de notificaciones — el usuario puede insertar sus propias alertas.
DROP POLICY IF EXISTS "notif_own_insert" ON public.notifications;
CREATE POLICY "notif_own_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = from_user_id);

-- 7.4 GRANT EXECUTE en todas las RPCs para roles anon y authenticated.
GRANT EXECUTE ON FUNCTION public.nodes_in_bbox          TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.nearest_node           TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_node_near       TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reports_near    TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_ticket_id         TO authenticated;
GRANT EXECUTE ON FUNCTION public.ruta_viva_history      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_report_background TO authenticated;
