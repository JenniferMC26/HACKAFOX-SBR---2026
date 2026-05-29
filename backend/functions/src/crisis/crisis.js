// Modo Crisis — usuario varado pide ayuda. Se busca punto seguro cercano, se
// notifica a contactos de emergencia y se mantiene una sesión activa que el
// contacto puede observar en tiempo real vía Supabase Realtime.
//
// Endpoints:
//   POST   /crisisStart            crea sesión
//   POST   /crisisUpdate           actualiza lat/lng (HTTP PUT semántico)
//   POST   /crisisResolve          marca como resuelta

const { supabase } = require('../shared/clients');
const { distanceMeters } = require('../routes/routing');

// Hardcoded — en prod Places API. Suficiente para demo.
const SAFE_POINTS = [
  { name: 'Hospital General de Tijuana',   lat: 32.5189, lng: -117.0289, type: 'hospital' },
  { name: 'Cruz Roja Tijuana',             lat: 32.5170, lng: -117.0246, type: 'clinic' },
  { name: 'Estación de Policía Centro',    lat: 32.5294, lng: -117.0297, type: 'police' },
  { name: 'IMSS Zona Río',                 lat: 32.5248, lng: -117.0284, type: 'hospital' },
  { name: 'Centro Comunitario Norte',      lat: 32.5350, lng: -117.0300, type: 'shelter' },
];

function nearestSafePoint(lat, lng) {
  let best = null;
  let bestDist = Infinity;
  for (const p of SAFE_POINTS) {
    const d = distanceMeters(lat, lng, p.lat, p.lng);
    if (d < bestDist) {
      best = { ...p, distanceMeters: Math.round(d) };
      bestDist = d;
    }
  }
  return best;
}

async function getProfile(uid) {
  const { data, error } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('uid', uid)
    .maybeSingle();
  if (error) throw new Error(`user_profiles.select: ${error.message}`);
  return data || { uid, mobility_type: 'none', emergency_contacts: [] };
}

async function notifyContacts(uid, sessionId, lat, lng, contacts) {
  if (!contacts || contacts.length === 0) return [];
  const rows = contacts.map((contactUid) => ({
    recipient_id: contactUid,
    type: 'crisis_started',
    from_user_id: uid,
    session_id: sessionId,
    lat,
    lng,
  }));
  const { error } = await supabase.from('notifications').insert(rows);
  if (error) {
    console.error('notifications.insert:', error.message);
    return [];
  }
  return contacts;
}

async function startCrisis({ uid, lat, lng }) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    const err = new Error('lat/lng requeridos');
    err.statusCode = 400;
    throw err;
  }
  const profile = await getProfile(uid);
  const safePoint = nearestSafePoint(lat, lng);

  const { data: session, error } = await supabase
    .from('crisis_sessions')
    .insert({
      user_id: uid,
      user_profile: profile,
      current_lat: lat,
      current_lng: lng,
      status: 'active',
      nearest_safe_point: safePoint,
      alerted_contacts: profile.emergency_contacts || [],
    })
    .select()
    .single();
  if (error) throw new Error(`crisis_sessions.insert: ${error.message}`);

  const alerted = await notifyContacts(uid, session.id, lat, lng, profile.emergency_contacts || []);
  return { sessionId: session.id, ...session, alertedContacts: alerted };
}

async function updateCrisis({ uid, sessionId, lat, lng }) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    const err = new Error('lat/lng requeridos');
    err.statusCode = 400;
    throw err;
  }
  const { data: existing, error: selErr } = await supabase
    .from('crisis_sessions')
    .select('user_id, status')
    .eq('id', sessionId)
    .maybeSingle();
  if (selErr) throw new Error(`crisis_sessions.select: ${selErr.message}`);
  if (!existing) {
    const err = new Error('Sesión no encontrada');
    err.statusCode = 404;
    throw err;
  }
  if (existing.user_id !== uid) {
    const err = new Error('No puedes actualizar una sesión que no es tuya');
    err.statusCode = 403;
    throw err;
  }
  const { error: updErr } = await supabase
    .from('crisis_sessions')
    .update({
      current_lat: lat,
      current_lng: lng,
      last_update: new Date().toISOString(),
    })
    .eq('id', sessionId);
  if (updErr) throw new Error(`crisis_sessions.update: ${updErr.message}`);
  return { sessionId, currentLat: lat, currentLng: lng };
}

async function resolveCrisis({ uid, sessionId }) {
  const { data: existing, error: selErr } = await supabase
    .from('crisis_sessions')
    .select('user_id, status')
    .eq('id', sessionId)
    .maybeSingle();
  if (selErr) throw new Error(`crisis_sessions.select: ${selErr.message}`);
  if (!existing) {
    const err = new Error('Sesión no encontrada');
    err.statusCode = 404;
    throw err;
  }
  if (existing.user_id !== uid) {
    const err = new Error('No puedes resolver una sesión que no es tuya');
    err.statusCode = 403;
    throw err;
  }
  const { error: updErr } = await supabase
    .from('crisis_sessions')
    .update({ status: 'resolved', resolved_at: new Date().toISOString() })
    .eq('id', sessionId);
  if (updErr) throw new Error(`crisis_sessions.update: ${updErr.message}`);
  return { sessionId, status: 'resolved' };
}

module.exports = { startCrisis, updateCrisis, resolveCrisis };
