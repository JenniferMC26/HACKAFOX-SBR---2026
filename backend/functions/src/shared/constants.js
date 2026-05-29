// Valores de negocio centralizados. Cualquier número mágico que aparezca en más
// de un módulo debe vivir aquí.

const TJ_BOUNDS = {
  latMin: 32.4,
  latMax: 32.7,
  lngMin: -117.2,
  lngMax: -116.8,
};

// Severity (1-10) viene de Gemini Vision. Score (0-10) es la métrica que usa el
// motor de ruteo. Score alto = más accesible.
function severityToScore(severity) {
  const s = Number(severity);
  if (!Number.isFinite(s)) return null;
  return Math.max(0, Math.min(10, 10 - s));
}

// Umbral mínimo de score por perfil. Si la ruta promedio cae debajo, se marca
// como no recomendada para ese perfil.
const THRESHOLDS = {
  wheelchair: 6,
  elderly: 4,
  cane: 4,
  stroller: 4,
  none: 0,
};

// Cache en memoria de Ruta Viva.
const RUTA_VIVA_CACHE_TTL_MS = 30 * 60 * 1000;

// Pesos al combinar histórico (temporal_patterns) con tiempo real (reports
// recientes). Ambos viven en Supabase.
const RUTA_VIVA_HISTORY_WEIGHT = 0.7;
const RUTA_VIVA_REALTIME_WEIGHT = 0.3;
const RUTA_VIVA_MIN_DATA_POINTS = 3;

// Radio para considerar que un reporte aplica a un nodo existente.
const REPORT_NEARBY_RADIUS_METERS = 30;

// Confianza mínima de Gemini para auto-aplicar el reporte.
const GEMINI_MIN_CONFIDENCE = 0.6;

// Severity a partir del cual se genera ticket cívico formal.
const TICKET_SEVERITY_THRESHOLD = 7;

// Rate limit de reportes ciudadanos.
const MAX_REPORTS_PER_HOUR = 5;

module.exports = {
  TJ_BOUNDS,
  severityToScore,
  THRESHOLDS,
  RUTA_VIVA_CACHE_TTL_MS,
  RUTA_VIVA_HISTORY_WEIGHT,
  RUTA_VIVA_REALTIME_WEIGHT,
  RUTA_VIVA_MIN_DATA_POINTS,
  REPORT_NEARBY_RADIUS_METERS,
  GEMINI_MIN_CONFIDENCE,
  TICKET_SEVERITY_THRESHOLD,
  MAX_REPORTS_PER_HOUR,
};
