// Modo Crisis — usuario varado puede pedir ayuda. Se busca punto seguro cercano,
// se notifica a contactos de emergencia y se mantiene una sesión activa que el
// contacto puede observar en tiempo real.
//
// Endpoints:
//   POST   /crisis/start           crea sesión
//   PUT    /crisis/:id/update      actualiza lat/lng
//   DELETE /crisis/:id/resolve     cierra sesión

const { randomUUID } = require('crypto');
const { db } = require('../shared/clients');
const { distanceMeters } = require('../shared/nodeUtils');

// Hardcoded — en prod Places API. Suficiente para demo.
const SAFE_POINTS = [
  { name: 'Hospital General de Tijuana',     lat: 32.5189, lng: -117.0289, type: 'hospital' },
  { name: 'Cruz Roja Tijuana',               lat: 32.5170, lng: -117.0246, type: 'clinic' },
  { name: 'Estación de Policía Centro',      lat: 32.5294, lng: -117.0297, type: 'police' },
  { name: 'IMSS Zona Río',                   lat: 32.5248, lng: -117.0284, type: 'hospital' },
  { name: 'Centro Comunitario Norte',        lat: 32.5350, lng: -117.0300, type: 'shelter' },
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

async function notifyContacts(uid, sessionId, lat, lng) {
  const snap = await db.ref(`users/${uid}/profile/emergencyContacts`).once('value');
  const contacts = snap.val() || [];
  const alerted = [];
  for (const contactUid of contacts) {
    const notifRef = db.ref(`users/${contactUid}/notifications`).push();
    await notifRef.set({
      type: 'crisis_started',
      fromUserId: uid,
      sessionId,
      lat,
      lng,
      read: false,
      createdAt: new Date().toISOString(),
    });
    alerted.push(contactUid);
  }
  return alerted;
}

async function startCrisis({ uid, lat, lng }) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    const err = new Error('lat/lng requeridos');
    err.statusCode = 400;
    throw err;
  }
  const profileSnap = await db.ref(`users/${uid}/profile`).once('value');
  const profile = profileSnap.val() || { mobilityType: 'none' };

  const sessionId = `crisis_${randomUUID().slice(0, 12)}`;
  const safePoint = nearestSafePoint(lat, lng);
  const alertedContacts = await notifyContacts(uid, sessionId, lat, lng);

  const session = {
    userId: uid,
    userProfile: profile,
    startedAt: new Date().toISOString(),
    currentLat: lat,
    currentLng: lng,
    status: 'active',
    nearestSafePoint: safePoint,
    alertedContacts,
  };
  await db.ref(`crisis_sessions/${sessionId}`).set(session);
  return { sessionId, ...session };
}

async function updateCrisis({ uid, sessionId, lat, lng }) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    const err = new Error('lat/lng requeridos');
    err.statusCode = 400;
    throw err;
  }
  const ref = db.ref(`crisis_sessions/${sessionId}`);
  const snap = await ref.once('value');
  if (!snap.exists()) {
    const err = new Error('Sesión no encontrada');
    err.statusCode = 404;
    throw err;
  }
  if (snap.val().userId !== uid) {
    const err = new Error('No puedes actualizar una sesión que no es tuya');
    err.statusCode = 403;
    throw err;
  }
  await ref.update({
    currentLat: lat,
    currentLng: lng,
    lastUpdate: new Date().toISOString(),
  });
  return { sessionId, currentLat: lat, currentLng: lng };
}

async function resolveCrisis({ uid, sessionId }) {
  const ref = db.ref(`crisis_sessions/${sessionId}`);
  const snap = await ref.once('value');
  if (!snap.exists()) {
    const err = new Error('Sesión no encontrada');
    err.statusCode = 404;
    throw err;
  }
  if (snap.val().userId !== uid) {
    const err = new Error('No puedes resolver una sesión que no es tuya');
    err.statusCode = 403;
    throw err;
  }
  await ref.update({
    status: 'resolved',
    resolvedAt: new Date().toISOString(),
  });
  return { sessionId, status: 'resolved' };
}

module.exports = { startCrisis, updateCrisis, resolveCrisis };
