-- ============================================================================
-- Migración 002 — Tablas faltantes + RPCs + Políticas + Realtime
--
-- Ejecutar en Supabase Dashboard → SQL Editor → New query.
-- Es idempotente: usa IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
--
-- Este script añade lo que faltaba en instancias donde solo se corrieron
-- las primeras 4 tablas (accessibility_nodes, reports, crisis_sessions,
-- user_profiles). Completa el esquema con:
--   - accessibility_reports  (analítica de reportes)
--   - temporal_patterns      (datos para Ruta Viva)
--   - civic_tickets          (tickets formales para municipio)
--   - Secuencia ticket_seq   (si no existe)
--   - Índices GIST y auxiliares
--   - RLS en las 3 tablas nuevas
--   - Función submit_report_background (SECURITY DEFINER)
--   - Políticas de crisis_sessions para authenticated
--   - Política de notificaciones insert para authenticated
--   - GRANT EXECUTE en todas las RPCs
--   - Realtime para crisis_sessions y notifications (idempotente)
-- ============================================================================

-- ── 0. Extensión (en caso de que no esté) ───────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;


-- ── 1. Tablas faltantes ──────────────────────────────────────────────────────

-- 1.1 Historial de reportes para analítica
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

-- 1.2 Patrones temporales para Ruta Viva
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

-- 1.3 Tickets cívicos formales para municipio
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

-- 1.4 Secuencia para ticket_id (PASO-YYYY-NNNN)
CREATE SEQUENCE IF NOT EXISTS public.ticket_seq START 1;


-- ── 2. Índices ────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_ar_location    ON public.accessibility_reports USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_tp_location    ON public.temporal_patterns     USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_tickets_location ON public.civic_tickets       USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_ar_reported_at  ON public.accessibility_reports (reported_at DESC);
CREATE INDEX IF NOT EXISTS idx_tp_hour_dow     ON public.temporal_patterns (hour_of_day, day_of_week);
CREATE INDEX IF NOT EXISTS idx_tickets_status  ON public.civic_tickets (status, created_at DESC);


-- ── 3. Row Level Security ────────────────────────────────────────────────────

ALTER TABLE public.accessibility_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporal_patterns     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.civic_tickets         ENABLE ROW LEVEL SECURITY;

-- accessibility_reports: solo service_role (contiene user_id sensible)
DROP POLICY IF EXISTS "ar_admin_all" ON public.accessibility_reports;
CREATE POLICY "ar_admin_all" ON public.accessibility_reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- temporal_patterns: lectura pública, escritura service_role
DROP POLICY IF EXISTS "tp_read_public" ON public.temporal_patterns;
CREATE POLICY "tp_read_public" ON public.temporal_patterns
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "tp_admin_write" ON public.temporal_patterns;
CREATE POLICY "tp_admin_write" ON public.temporal_patterns
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- civic_tickets: lectura pública (transparencia), escritura service_role
DROP POLICY IF EXISTS "tickets_read_public" ON public.civic_tickets;
CREATE POLICY "tickets_read_public" ON public.civic_tickets
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "tickets_admin_write" ON public.civic_tickets;
CREATE POLICY "tickets_admin_write" ON public.civic_tickets
  FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ── 4. RPC submit_report_background (SECURITY DEFINER) ──────────────────────
-- Inserta en accessibility_reports y opcionalmente en civic_tickets.
-- El browser llama esta función fire-and-forget después de crear el reporte.
-- SECURITY DEFINER porque ambas tablas solo permiten escritura a service_role.
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


-- ── 5. RPC next_ticket_id (si no existe) ────────────────────────────────────
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


-- ── 6. Políticas de crisis_sessions para authenticated ──────────────────────
-- El SPA necesita INSERT y UPDATE directos (sin Firebase Functions).
DROP POLICY IF EXISTS "crisis_own_insert" ON public.crisis_sessions;
CREATE POLICY "crisis_own_insert" ON public.crisis_sessions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "crisis_own_update" ON public.crisis_sessions;
CREATE POLICY "crisis_own_update" ON public.crisis_sessions
  FOR UPDATE TO authenticated
  USING (auth.uid()::text = user_id);


-- ── 7. Política de notificaciones insert para authenticated ──────────────────
DROP POLICY IF EXISTS "notif_own_insert" ON public.notifications;
CREATE POLICY "notif_own_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = from_user_id);


-- ── 8. GRANT EXECUTE en todas las RPCs ──────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.nodes_in_bbox            TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.nearest_node             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_node_near         TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reports_near      TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_ticket_id           TO authenticated;
GRANT EXECUTE ON FUNCTION public.ruta_viva_history        TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_report_background TO authenticated;


-- ── 9. Realtime — idempotente ────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'crisis_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.crisis_sessions;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;


-- ── Verificación ─────────────────────────────────────────────────────────────
-- Ejecuta esto después para confirmar que todo quedó bien:
--
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' ORDER BY table_name;
--
-- Debes ver: accessibility_nodes, accessibility_reports, civic_tickets,
--            crisis_sessions, notifications, reports, temporal_patterns,
--            user_profiles
