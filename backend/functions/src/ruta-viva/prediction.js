// Ruta Viva — predicción temporal de accesibilidad.
//
// 100% Supabase. Combina:
//   - Histórico: tabla temporal_patterns via RPC ruta_viva_history.
//   - Tiempo real: tabla reports (últimas 2h) via RPC recent_reports_near.
//
// Si no hay suficiente data histórica (< 3 puntos) devuelve fallback con
// applied: false. Cache en memoria con TTL 30 min por (lat, lng, hour, dow).

const { rutaVivaHistory, recentReportsNear } = require('../shared/nodeUtils');
const {
  RUTA_VIVA_CACHE_TTL_MS,
  RUTA_VIVA_HISTORY_WEIGHT,
  RUTA_VIVA_REALTIME_WEIGHT,
  RUTA_VIVA_MIN_DATA_POINTS,
} = require('../shared/constants');

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

async function recentRealtimeScore(lat, lng) {
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

  const history = await rutaVivaHistory(lat, lng, hour, dow);
  if (!history || history.dataPoints < RUTA_VIVA_MIN_DATA_POINTS) {
    const value = {
      applied: false,
      reason: 'Sin suficientes patrones históricos para esta hora/lugar',
      dataPoints: history ? history.dataPoints : 0,
    };
    cache.set(key, { value, expiresAt: Date.now() + RUTA_VIVA_CACHE_TTL_MS });
    return value;
  }

  const realtime = await recentRealtimeScore(lat, lng);
  const combined = realtime == null
    ? history.avgScore
    : history.avgScore * RUTA_VIVA_HISTORY_WEIGHT + realtime * RUTA_VIVA_REALTIME_WEIGHT;

  const predictedScore = Math.round(combined * 100) / 10;
  const reason = history.hasEvent
    ? 'Patrón histórico indica evento o congestión recurrente en este horario'
    : 'Patrón histórico estable para este horario';

  const value = {
    applied: true,
    predictedScore,
    reason,
    dataPoints: history.dataPoints,
    historicalScore: Math.round(history.avgScore * 100) / 10,
    realtimeScore: realtime == null ? null : Math.round(realtime * 100) / 10,
    hour,
    dayOfWeek: dow,
  };
  cache.set(key, { value, expiresAt: Date.now() + RUTA_VIVA_CACHE_TTL_MS });
  return value;
}

module.exports = { getRutaVivaScore };
