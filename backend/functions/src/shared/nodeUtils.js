// Wrappers sobre las stored functions PostGIS definidas en supabase-schema.sql.
// Toda lógica geoespacial se ejecuta en Postgres — JS solo orquesta.

const { supabase } = require('./clients');

async function findNodesInBoundingBox(bounds) {
  const { data, error } = await supabase.rpc('nodes_in_bbox', {
    p_lat_min: bounds.latMin,
    p_lat_max: bounds.latMax,
    p_lng_min: bounds.lngMin,
    p_lng_max: bounds.lngMax,
  });
  if (error) throw new Error(`nodes_in_bbox: ${error.message}`);
  return (data || []).map((n) => ({
    nodeId: n.id,
    lat: n.lat,
    lng: n.lng,
    type: n.type,
    accessible: n.accessible,
    score: n.score,
    source: n.source,
    barrierType: n.barrier_type,
    lastReported: n.last_reported,
    reportCount: n.report_count,
    photoUrl: n.photo_url,
    geminiAnalysis: n.gemini_analysis,
  }));
}

async function findNearestNode(lat, lng, radiusMeters) {
  const { data, error } = await supabase.rpc('nearest_node', {
    p_lat: lat,
    p_lng: lng,
    p_radius_m: radiusMeters,
  });
  if (error) throw new Error(`nearest_node: ${error.message}`);
  const n = data && data[0];
  if (!n) return null;
  return {
    nodeId: n.id,
    lat: n.lat,
    lng: n.lng,
    type: n.type,
    accessible: n.accessible,
    score: n.score,
    source: n.source,
    barrierType: n.barrier_type,
    lastReported: n.last_reported,
    reportCount: n.report_count,
    photoUrl: n.photo_url,
    geminiAnalysis: n.gemini_analysis,
    distanceMeters: n.distance_m,
  };
}

// Upsert atómico (find-near-or-create) — encapsulado en SQL para evitar race.
async function upsertNodeNear({
  lat,
  lng,
  radiusMeters,
  type,
  accessible,
  score,
  barrierType,
  photoUrl,
  geminiAnalysis,
  source = 'field_verified',
}) {
  const { data, error } = await supabase.rpc('upsert_node_near', {
    p_lat: lat,
    p_lng: lng,
    p_radius_m: radiusMeters,
    p_type: type,
    p_accessible: accessible,
    p_score: score,
    p_barrier_type: barrierType,
    p_photo_url: photoUrl,
    p_gemini_analysis: geminiAnalysis,
    p_source: source,
  });
  if (error) throw new Error(`upsert_node_near: ${error.message}`);
  const n = data && (Array.isArray(data) ? data[0] : data);
  if (!n) throw new Error('upsert_node_near no devolvió fila');
  return {
    nodeId: n.id,
    lat: n.lat,
    lng: n.lng,
    type: n.type,
    accessible: n.accessible,
    score: n.score,
    source: n.source,
    barrierType: n.barrier_type,
    photoUrl: n.photo_url,
    geminiAnalysis: n.gemini_analysis,
    reportCount: n.report_count,
  };
}

async function recentReportsNear(lat, lng, radiusMeters, windowSeconds) {
  const { data, error } = await supabase.rpc('recent_reports_near', {
    p_lat: lat,
    p_lng: lng,
    p_radius_m: radiusMeters,
    p_window_seconds: windowSeconds,
  });
  if (error) throw new Error(`recent_reports_near: ${error.message}`);
  return data || [];
}

async function nextTicketId() {
  const { data, error } = await supabase.rpc('next_ticket_id');
  if (error) throw new Error(`next_ticket_id: ${error.message}`);
  return data;
}

module.exports = {
  findNodesInBoundingBox,
  findNearestNode,
  upsertNodeNear,
  recentReportsNear,
  nextTicketId,
};
