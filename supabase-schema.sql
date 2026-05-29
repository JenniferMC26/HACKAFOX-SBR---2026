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

-- 1.6 Secuencia atómica para ticket_id formateado como PASO-YYYY-NNNN.
CREATE SEQUENCE IF NOT EXISTS public.ticket_seq START 1;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Índices
-- ────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_nodes_location    ON public.accessibility_nodes USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_reports_location  ON public.reports             USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_crisis_location   ON public.crisis_sessions     USING GIST (current_location);

CREATE INDEX IF NOT EXISTS idx_reports_user_created ON public.reports (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_recipient_read ON public.notifications (recipient_id, read);


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
-- Evita el race del find-then-insert separado.
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
LANGUAGE plpgsql AS $$
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
CREATE OR REPLACE FUNCTION public.recent_reports_near(
  p_lat FLOAT8, p_lng FLOAT8, p_radius_m FLOAT8, p_window_seconds INT
) RETURNS TABLE(gemini_analysis JSONB, created_at TIMESTAMPTZ)
LANGUAGE sql STABLE AS $$
  SELECT r.gemini_analysis, r.created_at
  FROM public.reports r
  WHERE r.created_at >= NOW() - (p_window_seconds || ' seconds')::interval
    AND ST_DWithin(r.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m);
$$;

-- 3.5 Siguiente ticket ID atómico (PASO-YYYY-NNNN).
CREATE OR REPLACE FUNCTION public.next_ticket_id()
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
  seq_val BIGINT;
  yr      INT;
BEGIN
  seq_val := nextval('public.ticket_seq');
  yr      := EXTRACT(YEAR FROM NOW())::INT;
  RETURN format('PASO-%s-%s', yr, lpad(seq_val::text, 4, '0'));
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Row Level Security
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accessibility_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crisis_sessions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;

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
