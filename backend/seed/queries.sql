-- =============================================================
-- Paso — BigQuery Queries
-- Proyecto: paso | Dataset: paso | Región: US
--
-- CÓMO USAR:
--   PARTE A (líneas 1–180)  → Ejecutar directo en BigQuery Console.
--                             Correr cada bloque por separado con el botón "Run".
--   PARTE B (líneas 181+)   → Templates para Node.js. Los @params son sustituidos
--                             por el cliente de BigQuery en las Cloud Functions.
--                             No corren directo en consola sin editar los valores.
-- =============================================================


-- ════════════════════════════════════════════════════════════════
-- PARTE A — EJECUTAR EN BIGQUERY CONSOLE
-- ════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────
-- A1. Crear dataset (solo una vez)
-- ─────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS `paso`
  OPTIONS (location = 'US');


-- ─────────────────────────────────────────
-- A2. Crear tablas (correr cada una por separado)
-- ─────────────────────────────────────────

-- Tabla 1: historial de reportes ciudadanos
CREATE TABLE IF NOT EXISTS `paso.accessibility_reports` (
  report_id         STRING    NOT NULL,   -- UUID generado en report.js
  user_id           STRING    NOT NULL,   -- uid de Firebase Auth (anónimo)
  lat               FLOAT64   NOT NULL,
  lng               FLOAT64   NOT NULL,
  barrier_type      STRING,               -- 'rampa_rota' | 'banqueta_bloqueada' | etc.
  severity          INT64,                -- 1–10 (viene de Gemini Vision)
  hour_of_day       INT64,                -- 0–23, extraído al insertar
  day_of_week       INT64,                -- 0=lunes … 6=domingo
  weather_condition STRING,
  reported_at       TIMESTAMP NOT NULL,
  resolved_at       TIMESTAMP             -- NULL hasta resolución
);

-- Tabla 2: patrones temporales para Ruta Viva
CREATE TABLE IF NOT EXISTS `paso.temporal_patterns` (
  lat                 FLOAT64 NOT NULL,
  lng                 FLOAT64 NOT NULL,
  hour_of_day         INT64   NOT NULL,   -- 0–23
  day_of_week         INT64   NOT NULL,   -- 0=lunes … 6=domingo
  accessibility_score FLOAT64 NOT NULL,   -- 0.0 inaccesible → 1.0 accesible
  event_flag          BOOL    DEFAULT FALSE,
  report_count        INT64   DEFAULT 0
);

-- Tabla 3: tickets formales para el municipio (severity >= 7)
CREATE TABLE IF NOT EXISTS `paso.civic_tickets` (
  ticket_id               STRING    NOT NULL,  -- PASO-YYYY-NNNN (counter en RTDB)
  report_id               STRING    NOT NULL,
  lat                     FLOAT64   NOT NULL,
  lng                     FLOAT64   NOT NULL,
  barrier_type            STRING,
  severity                INT64,
  photo_url               STRING,
  gemini_description      STRING,
  affected_users_estimate INT64,
  created_at              TIMESTAMP NOT NULL,
  assigned_to             STRING,
  status                  STRING    DEFAULT 'open'  -- 'open' | 'assigned' | 'resolved'
);


-- ─────────────────────────────────────────
-- A3. Seed — patrones temporales iniciales
-- Correr completo de una vez (un solo INSERT con todos los VALUES)
-- ─────────────────────────────────────────
INSERT INTO `paso.temporal_patterns`
  (lat, lng, hour_of_day, day_of_week, accessibility_score, event_flag, report_count)
VALUES
  -- Mercado Hidalgo (32.5266, -117.0382)
  (32.5266, -117.0382,  7, 0, 0.80, FALSE, 0),  -- lunes 7am
  (32.5266, -117.0382,  8, 0, 0.75, FALSE, 1),  -- lunes 8am
  (32.5266, -117.0382, 10, 0, 0.75, FALSE, 1),  -- lunes 10am sin evento
  (32.5266, -117.0382, 12, 0, 0.60, FALSE, 2),  -- lunes mediodía
  (32.5266, -117.0382,  8, 2, 0.70, FALSE, 1),  -- miércoles 8am
  (32.5266, -117.0382, 10, 2, 0.45, FALSE, 3),  -- miércoles 10am congestión
  (32.5266, -117.0382, 12, 2, 0.40, FALSE, 4),  -- miércoles mediodía alta congestión
  (32.5266, -117.0382, 10, 5, 0.35, TRUE,  5),  -- sábado 10am día de mercado
  (32.5266, -117.0382, 12, 5, 0.30, TRUE,  7),  -- sábado mediodía máxima congestión
  (32.5266, -117.0382, 16, 5, 0.50, TRUE,  3),  -- sábado 4pm bajando

  -- Zona Centro / Av. Revolución (32.5322, -117.0281)
  (32.5322, -117.0281, 10, 0, 0.70, FALSE, 1),  -- lunes 10am
  (32.5322, -117.0281, 14, 4, 0.55, FALSE, 2),  -- viernes 2pm moderado
  (32.5322, -117.0281, 20, 4, 0.30, FALSE, 4),  -- viernes 8pm muy concurrido
  (32.5322, -117.0281, 22, 4, 0.25, FALSE, 5),  -- viernes 10pm máxima ocupación
  (32.5322, -117.0281, 14, 5, 0.35, FALSE, 3),  -- sábado 2pm
  (32.5322, -117.0281, 20, 5, 0.20, FALSE, 6),  -- sábado 8pm peor momento

  -- Hospital General de Tijuana (32.5193, -117.0289)
  (32.5193, -117.0289,  7, 0, 0.85, FALSE, 0),  -- lunes 7am accesible
  (32.5193, -117.0289,  9, 1, 0.80, FALSE, 0),  -- martes 9am
  (32.5193, -117.0289,  9, 3, 0.65, FALSE, 1),  -- jueves 9am moderado
  (32.5193, -117.0289, 12, 3, 0.55, FALSE, 2),  -- jueves mediodía

  -- Plaza Río (32.5258, -117.0327)
  (32.5258, -117.0327, 11, 6, 0.50, FALSE, 2),  -- domingo 11am
  (32.5258, -117.0327, 15, 6, 0.40, FALSE, 3),  -- domingo 3pm
  (32.5258, -117.0327, 17, 5, 0.35, FALSE, 4),  -- sábado 5pm

  -- Parque Morelos (32.5301, -117.0197)
  (32.5301, -117.0197,  9, 0, 0.90, FALSE, 0),  -- lunes 9am muy accesible
  (32.5301, -117.0197, 10, 6, 0.75, FALSE, 1),  -- domingo 10am
  (32.5301, -117.0197, 15, 6, 0.65, FALSE, 1);  -- domingo 3pm


-- ─────────────────────────────────────────
-- A4. Verificar que el seed quedó bien
-- ─────────────────────────────────────────
SELECT
  COUNT(*) AS total_patrones,
  COUNT(DISTINCT CONCAT(CAST(ROUND(lat,3) AS STRING), ',', CAST(ROUND(lng,3) AS STRING))) AS zonas
FROM `paso.temporal_patterns`;


-- ─────────────────────────────────────────
-- A5. Queries de monitoreo — correr ad hoc en consola
-- ─────────────────────────────────────────

-- Reportes por tipo de barrera (últimas 24h)
SELECT
  barrier_type,
  COUNT(*)                AS total,
  ROUND(AVG(severity), 1) AS severidad_promedio,
  COUNTIF(severity >= 7)  AS tickets_generados
FROM `paso.accessibility_reports`
WHERE reported_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY barrier_type
ORDER BY total DESC;


-- Zonas con peor accesibilidad acumulada
SELECT
  ROUND(lat, 2) AS lat_zona,
  ROUND(lng, 2) AS lng_zona,
  COUNT(*)                AS reportes,
  ROUND(AVG(severity), 1) AS severidad_promedio
FROM `paso.accessibility_reports`
GROUP BY lat_zona, lng_zona
HAVING reportes >= 3
ORDER BY severidad_promedio DESC
LIMIT 10;


-- Tickets abiertos (panel municipal)
SELECT
  ticket_id,
  barrier_type,
  severity,
  ROUND(lat, 4) AS lat,
  ROUND(lng, 4) AS lng,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M', created_at, 'America/Tijuana') AS creado,
  assigned_to,
  status
FROM `paso.civic_tickets`
WHERE status != 'resolved'
ORDER BY severity DESC, created_at ASC;


-- Score por hora en Mercado Hidalgo (validar que el seed tiene sentido)
SELECT
  hour_of_day                        AS hora,
  ROUND(AVG(accessibility_score), 2) AS score_promedio,
  MAX(event_flag)                    AS con_evento,
  SUM(report_count)                  AS reportes_historicos
FROM `paso.temporal_patterns`
WHERE ST_DISTANCE(
        ST_GEOGPOINT(-117.0382, 32.5266),
        ST_GEOGPOINT(lng, lat)
      ) <= 500
GROUP BY hora
ORDER BY hora;


-- Resumen diario (dashboard del hackathon)
SELECT
  DATE(reported_at, 'America/Tijuana') AS fecha,
  COUNT(*)                              AS reportes,
  COUNTIF(severity >= 7)               AS tickets,
  ROUND(AVG(severity), 1)              AS severidad_promedio
FROM `paso.accessibility_reports`
GROUP BY fecha
ORDER BY fecha DESC
LIMIT 30;


-- SEGURIDAD — Usuarios con actividad sospechosa (más de 10 reportes en 1 hora)
-- Útil para detectar abuso y ajustar el rate limit si es necesario.
SELECT
  user_id,
  FORMAT_TIMESTAMP('%Y-%m-%dT%H', reported_at, 'America/Tijuana') AS hora,
  COUNT(*) AS reportes_en_hora
FROM `paso.accessibility_reports`
GROUP BY user_id, hora
HAVING reportes_en_hora > 10
ORDER BY reportes_en_hora DESC;


-- Marcar reporte como resuelto (reemplazar el ID real antes de correr)
UPDATE `paso.accessibility_reports`
SET resolved_at = CURRENT_TIMESTAMP()
WHERE report_id = 'REEMPLAZAR-CON-ID-REAL';


-- Actualizar status de ticket (reemplazar valores antes de correr)
UPDATE `paso.civic_tickets`
SET
  status      = 'assigned',           -- 'assigned' | 'resolved'
  assigned_to = 'nombre.responsable'
WHERE ticket_id = 'PASO-2026-0001';   -- reemplazar con ticket real


-- ════════════════════════════════════════════════════════════════
-- PARTE B — TEMPLATES BACKEND (Node.js / @google-cloud/bigquery)
-- NO ejecutar directo en consola — los @params son sustituidos
-- por el cliente de BigQuery en las Cloud Functions.
-- ════════════════════════════════════════════════════════════════


-- B1. report.js (Fase 3) — insertar reporte ciudadano
-- Fire-and-forget después de actualizar /accessibility_layer en RTDB.
-- Uso: bigquery.query({ query: INSERT_REPORT, params: { report_id, user_id, ... } })
INSERT INTO `paso.accessibility_reports`
  (report_id, user_id, lat, lng, barrier_type, severity,
   hour_of_day, day_of_week, weather_condition, reported_at)
VALUES
  (@report_id, @user_id, @lat, @lng, @barrier_type, @severity,
   @hour_of_day, @day_of_week, @weather_condition, CURRENT_TIMESTAMP());


-- B2. report.js (Fase 3) — insertar ticket cívico cuando severity >= 7
-- El @ticket_id viene de RTDB /counters/ticketSeq formateado como PASO-YYYY-NNNN.
INSERT INTO `paso.civic_tickets`
  (ticket_id, report_id, lat, lng, barrier_type, severity,
   photo_url, gemini_description, affected_users_estimate, created_at, status)
VALUES
  (@ticket_id, @report_id, @lat, @lng, @barrier_type, @severity,
   @photo_url, @gemini_description, @affected_users_estimate, CURRENT_TIMESTAMP(), 'open');


-- B3. prediction.js (Fase 4) — score predictivo Ruta Viva, radio 200m
-- Si retorna < 3 filas → fallback con applied: false.
SELECT
  lat,
  lng,
  accessibility_score,
  event_flag,
  report_count,
  ST_DISTANCE(
    ST_GEOGPOINT(@lng, @lat),
    ST_GEOGPOINT(lng, lat)
  ) AS distance_meters
FROM `paso.temporal_patterns`
WHERE
  hour_of_day = @hour_of_day
  AND day_of_week = @day_of_week
  AND ST_DISTANCE(
        ST_GEOGPOINT(@lng, @lat),
        ST_GEOGPOINT(lng, lat)
      ) <= 200
ORDER BY distance_meters ASC;


-- B4. prediction.js (Fase 4) — score agregado (alternativa a promediar en Node.js)
SELECT
  AVG(accessibility_score) AS avg_score,
  COUNT(*)                 AS data_points,
  MAX(event_flag)          AS has_event
FROM `paso.temporal_patterns`
WHERE
  hour_of_day = @hour_of_day
  AND day_of_week = @day_of_week
  AND ST_DISTANCE(
        ST_GEOGPOINT(@lng, @lat),
        ST_GEOGPOINT(lng, lat)
      ) <= 200;


-- B5. crisis.js (Fase 6) — marcar reporte como resuelto al cerrar sesión
UPDATE `paso.accessibility_reports`
SET    resolved_at = CURRENT_TIMESTAMP()
WHERE  report_id   = @report_id;


-- B6. Admin — actualizar status de ticket desde Cloud Function
UPDATE `paso.civic_tickets`
SET
  status      = @status,
  assigned_to = @assigned_to
WHERE ticket_id = @ticket_id;
