// Puente Ciudadano — recibe un reporte (foto ya subida a Supabase Storage), lo
// analiza con Gemini, hace upsert atómico en accessibility_nodes, e inserta el
// espejo histórico en accessibility_reports + ticket cívico si severity >= 7.

const { supabase } = require('../shared/clients');
const { upsertNodeNear, nextTicketId } = require('../shared/nodeUtils');
const {
  severityToScore,
  REPORT_NEARBY_RADIUS_METERS,
  GEMINI_MIN_CONFIDENCE,
  TICKET_SEVERITY_THRESHOLD,
  MAX_REPORTS_PER_HOUR,
  TJ_BOUNDS,
} = require('../shared/constants');
const { analyzeBarrierPhoto } = require('./geminiVision');

function validatePhotoUrl(photoUrl) {
  if (!process.env.SUPABASE_URL) return false;
  const baseHost = process.env.SUPABASE_URL.replace(/\/$/, '');
  const allowed = [
    `${baseHost}/storage/v1/object/public/reports/`,
    `${baseHost}/storage/v1/object/sign/reports/`,
    `${baseHost}/storage/v1/object/authenticated/reports/`,
  ];
  return allowed.some((p) => photoUrl.startsWith(p));
}

async function checkRateLimit(uid) {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from('reports')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', uid)
    .gte('created_at', oneHourAgo);
  if (error) throw new Error(`rate_limit_check: ${error.message}`);
  return (count || 0) < MAX_REPORTS_PER_HOUR;
}

// Fire-and-forget — un fallo aquí no debe bloquear la respuesta al cliente.
async function insertHistory(table, row) {
  const { error } = await supabase.from(table).insert(row);
  if (error) console.error(`${table}.insert:`, error.message);
}

async function submitReport({ uid, lat, lng, photoUrl, weather }) {
  // 1. Validaciones
  if (
    !Number.isFinite(lat) || !Number.isFinite(lng) ||
    lat < TJ_BOUNDS.latMin || lat > TJ_BOUNDS.latMax ||
    lng < TJ_BOUNDS.lngMin || lng > TJ_BOUNDS.lngMax
  ) {
    const err = new Error('Coordenadas fuera del bounding box de Tijuana');
    err.statusCode = 400;
    throw err;
  }
  if (!validatePhotoUrl(photoUrl)) {
    const err = new Error('photoUrl no pertenece al bucket autorizado');
    err.statusCode = 400;
    throw err;
  }

  // 2. Rate limit
  const withinLimit = await checkRateLimit(uid);
  if (!withinLimit) {
    const err = new Error('Límite de reportes por hora alcanzado');
    err.statusCode = 429;
    throw err;
  }

  // 3. Gemini
  const analysis = await analyzeBarrierPhoto(photoUrl);
  const score = severityToScore(analysis.severity);
  const requiresHumanReview = analysis.confidence < GEMINI_MIN_CONFIDENCE;

  // 4. Upsert atómico en accessibility_nodes
  const node = await upsertNodeNear({
    lat,
    lng,
    radiusMeters: REPORT_NEARBY_RADIUS_METERS,
    type: 'sidewalk',
    accessible: score >= 5,
    score,
    barrierType: analysis.barrierType === 'none' ? null : analysis.barrierType,
    photoUrl,
    geminiAnalysis: analysis,
    source: 'field_verified',
  });

  // 5. Ticket cívico si severity alto
  let ticketId = null;
  if (analysis.severity >= TICKET_SEVERITY_THRESHOLD) {
    ticketId = await nextTicketId();
  }

  // 6. Insert del reporte
  const { data: reportRow, error: reportErr } = await supabase
    .from('reports')
    .insert({
      user_id: uid,
      lat,
      lng,
      photo_url: photoUrl,
      gemini_analysis: analysis,
      requires_human_review: requiresHumanReview,
      status: 'pending',
      ticket_id: ticketId,
    })
    .select()
    .single();
  if (reportErr) throw new Error(`reports.insert: ${reportErr.message}`);

  // 7. Espejo histórico en accessibility_reports (fire-and-forget)
  // FIX: use Tijuana local time (UTC-7) — not UTC — so temporal analytics
  // match the actual hour/day the user experienced the barrier.
  const now = new Date();
  const tjParts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Tijuana',
    hour: 'numeric',
    weekday: 'short',
    hour12: false,
  }).formatToParts(now);
  const hourTJ = parseInt(tjParts.find((p) => p.type === 'hour').value, 10);
  const dowMapTJ = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  const dowTJ = dowMapTJ[tjParts.find((p) => p.type === 'weekday').value];

  insertHistory('accessibility_reports', {
    report_id: reportRow.id,
    user_id: uid,
    lat,
    lng,
    barrier_type: analysis.barrierType,
    severity: analysis.severity,
    hour_of_day: hourTJ,
    day_of_week: dowTJ,
    weather_condition: weather || null,
    reported_at: reportRow.created_at,
  });

  // 8. Ticket cívico (fire-and-forget)
  if (ticketId) {
    insertHistory('civic_tickets', {
      ticket_id: ticketId,
      report_id: reportRow.id,
      lat,
      lng,
      barrier_type: analysis.barrierType,
      severity: analysis.severity,
      photo_url: photoUrl,
      gemini_description: analysis.description,
      affected_users_estimate: (analysis.affectedProfiles || []).length * 100,
      created_at: reportRow.created_at,
      status: 'open',
    });
  }

  return {
    reportId: reportRow.id,
    ticketId,
    nodeId: node.nodeId,
    score,
    requiresHumanReview,
    analysis,
  };
}

module.exports = { submitReport };
