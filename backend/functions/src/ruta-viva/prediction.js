// Ruta Viva — predicción temporal de accesibilidad.
//
// Combina histórico (BigQuery temporal_patterns) + tiempo real (RTDB recent reports).
// Si GOOGLE_APPLICATION_CREDENTIALS no está seteado (modo emulador), se usa un
// MOCK con datos sintéticos basados en hour_of_day / day_of_week.

const { db, bigquery, BQ_DATASET } = require('../shared/clients');
const {
  RUTA_VIVA_CACHE_TTL_MS,
  RUTA_VIVA_BQ_WEIGHT,
  RUTA_VIVA_FIREBASE_WEIGHT,
  RUTA_VIVA_MIN_DATA_POINTS,
} = require('../shared/constants');

const USE_MOCK_BQ = !process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.GCLOUD_PROJECT_PROD;

// Cache en memoria per-instance. Suficiente para hackathon.
const cache = new Map();
function cacheKey(lat, lng, hour, dow) {
  const lr = Math.round(lat * 1000) / 1000;
  const lgr = Math.round(lng * 1000) / 1000;
  return `${lr},${lgr},${hour},${dow}`;
}

function parseIsoToTijuanaHourDow(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) throw new Error('arrivalTime inválido');
  // Tijuana usa America/Tijuana (UTC-8 / UTC-7 DST). Si el cliente manda offset
  // explícito, Date ya conoce el wall-clock real — usamos UTC del Date como
  // proxy del momento absoluto y derivamos hora local con Intl.
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
  // Punto de referencia: Mercado Hidalgo (32.5266, -117.0382) — los miércoles
  // 10–14 caen a score 0.2 con event_flag.
  const distToMercado = Math.hypot(lat - 32.5266, lng + 117.0382);
  if (distToMercado < 0.003 && dow === 2 && hour >= 10 && hour <= 14) {
    return { avgScore: 0.25, dataPoints: 5, hasEvent: true };
  }
  if (distToMercado < 0.003 && dow === 5 && hour >= 8 && hour <= 16) {
    return { avgScore: 0.35, dataPoints: 4, hasEvent: true };
  }
  // Hora pico: 7-9 y 17-19 entre semana → score más bajo.
  if (dow < 5 && ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19))) {
    return { avgScore: 0.55, dataPoints: 3, hasEvent: false };
  }
  // Madrugada: alta accesibilidad.
  if (hour <= 5) return { avgScore: 0.92, dataPoints: 4, hasEvent: false };
  // Default neutro pero con suficientes data points para no caer al fallback.
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

  const [rows] = await bigquery.query({
    query,
    params: { lat, lng, hour, dow },
  });
  const row = rows[0] || {};
  return {
    avgScore: row.avg_score == null ? null : Number(row.avg_score),
    dataPoints: Number(row.data_points || 0),
    hasEvent: !!row.has_event,
  };
}

async function recentFirebaseScore(lat, lng) {
  // Promedio de score de nodos a < 200m con reporte en las últimas 2h.
  const cutoff = Date.now() - 2 * 60 * 60 * 1000;
  const dLat = 200 / 111_000;
  const dLng = 200 / (111_000 * Math.cos((lat * Math.PI) / 180));
  const { findNodesInBoundingBox } = require('../shared/nodeUtils');
  const nodes = await findNodesInBoundingBox({
    latMin: lat - dLat,
    latMax: lat + dLat,
    lngMin: lng - dLng,
    lngMax: lng + dLng,
  });
  const recent = nodes.filter((n) => n.lastReported && new Date(n.lastReported).getTime() >= cutoff);
  if (recent.length === 0) return null;
  const avg = recent.reduce((s, n) => s + n.score, 0) / recent.length;
  return avg / 10; // normaliza a 0..1
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

  const recent = await recentFirebaseScore(lat, lng);
  const combined = recent == null
    ? bq.avgScore
    : bq.avgScore * RUTA_VIVA_BQ_WEIGHT + recent * RUTA_VIVA_FIREBASE_WEIGHT;

  const predictedScore = Math.round(combined * 100) / 10; // 0..10 con 1 decimal
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
