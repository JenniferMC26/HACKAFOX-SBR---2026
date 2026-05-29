// Ruta Viva — predicción temporal de accesibilidad.
//
// Combina histórico (BigQuery temporal_patterns) + tiempo real (Supabase reports
// recientes via RPC recent_reports_near).
//
// Si GOOGLE_APPLICATION_CREDENTIALS no está seteado (sin creds GCP), BigQuery
// usa un MOCK con datos sintéticos basados en hour_of_day / day_of_week.

const { bigquery, BQ_DATASET } = require('../shared/clients');
const { recentReportsNear } = require('../shared/nodeUtils');
const {
  RUTA_VIVA_CACHE_TTL_MS,
  RUTA_VIVA_BQ_WEIGHT,
  RUTA_VIVA_SUPABASE_WEIGHT,
  RUTA_VIVA_MIN_DATA_POINTS,
} = require('../shared/constants');

const USE_MOCK_BQ = !process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.GCLOUD_PROJECT_PROD;

const cache = new Map();
function cacheKey(lat, lng, hour, dow) {
  const lr = Math.round(lat * 1000) / 1000;
  const lgr = Math.round(lng * 1000) / 1000;
  return `${lr},${lgr},${hour},${dow}`;
}

function parseIsoToTijuanaHourDow(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) throw new Error('arrivalTime inválido');
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Tijuana',
    hour: 'numeric',
    weekday: 'short',
    hour12: false,
  }).formatToParts(d);
  const hour = parseInt(parts.find((p) => p.type === 'hour').value, 10);
  const dowMap = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  const dow = dowMap[parts.find((p) => p.type === 'weekday').value];
  return { hour, dow };
}

function mockBqQuery(lat, lng, hour, dow) {
  const distToMercado = Math.hypot(lat - 32.5266, lng + 117.0382);
  if (distToMercado < 0.003 && dow === 2 && hour >= 10 && hour <= 14) {
    return { avgScore: 0.25, dataPoints: 5, hasEvent: true };
  }
  if (distToMercado < 0.003 && dow === 5 && hour >= 8 && hour <= 16) {
    return { avgScore: 0.35, dataPoints: 4, hasEvent: true };
  }
  if (dow < 5 && ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19))) {
    return { avgScore: 0.55, dataPoints: 3, hasEvent: false };
  }
  if (hour <= 5) return { avgScore: 0.92, dataPoints: 4, hasEvent: false };
  return { avgScore: 0.75, dataPoints: 3, hasEvent: false };
}

async function queryBigQuery(lat, lng, hour, dow) {
  if (USE_MOCK_BQ) return mockBqQuery(lat, lng, hour, dow);
  const query = `
    SELECT
      AVG(accessibility_score) AS avg_score,
      COUNT(*) AS data_points,
      MAX(event_flag) AS has_event
    FROM \`${BQ_DATASET}.temporal_patterns\`
    WHERE
      hour_of_day = @hour
      AND day_of_week = @dow
      AND ST_DISTANCE(ST_GEOGPOINT(@lng, @lat), ST_GEOGPOINT(lng, lat)) <= 200`;
  const [rows] = await bigquery.query({ query, params: { lat, lng, hour, dow } });
  const row = rows[0] || {};
  return {
    avgScore: row.avg_score == null ? null : Number(row.avg_score),
    dataPoints: Number(row.data_points || 0),
    hasEvent: !!row.has_event,
  };
}

async function recentSupabaseScore(lat, lng) {
  const recent = await recentReportsNear(lat, lng, 200, 2 * 60 * 60);
  if (recent.length === 0) return null;
  let sum = 0;
  let n = 0;
  for (const r of recent) {
    const sev = r.gemini_analysis && r.gemini_analysis.severity;
    if (Number.isFinite(sev)) {
      sum += (10 - sev) / 10; // score normalizado 0..1
      n++;
    }
  }
  return n === 0 ? null : sum / n;
}

async function getRutaVivaScore(lat, lng, arrivalTimeIso) {
  const { hour, dow } = parseIsoToTijuanaHourDow(arrivalTimeIso);
  const key = cacheKey(lat, lng, hour, dow);
  const cached = cache.get(key);
  if (cached && cached.expiresAt > Date.now()) return cached.value;

  const bq = await queryBigQuery(lat, lng, hour, dow);
  if (!bq || bq.dataPoints < RUTA_VIVA_MIN_DATA_POINTS) {
    const value = {
      applied: false,
      reason: 'Sin suficientes patrones históricos para esta hora/lugar',
      dataPoints: bq ? bq.dataPoints : 0,
    };
    cache.set(key, { value, expiresAt: Date.now() + RUTA_VIVA_CACHE_TTL_MS });
    return value;
  }

  const recent = await recentSupabaseScore(lat, lng);
  const combined = recent == null
    ? bq.avgScore
    : bq.avgScore * RUTA_VIVA_BQ_WEIGHT + recent * RUTA_VIVA_SUPABASE_WEIGHT;

  const predictedScore = Math.round(combined * 100) / 10;
  const reason = bq.hasEvent
    ? 'Patrón histórico indica evento o congestión recurrente en este horario'
    : 'Patrón histórico estable para este horario';

  const value = {
    applied: true,
    predictedScore,
    reason,
    dataPoints: bq.dataPoints,
    historicalScore: Math.round(bq.avgScore * 100) / 10,
    realtimeScore: recent == null ? null : Math.round(recent * 100) / 10,
    hour,
    dayOfWeek: dow,
    mock: USE_MOCK_BQ,
  };
  cache.set(key, { value, expiresAt: Date.now() + RUTA_VIVA_CACHE_TTL_MS });
  return value;
}

module.exports = { getRutaVivaScore };
