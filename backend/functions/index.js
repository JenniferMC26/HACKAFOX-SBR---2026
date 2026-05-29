// Registro de Cloud Functions. CORS habilitado en todas para permitir el HTML
// de prueba servido desde localhost:5000 (hosting emulator) o file://.

const { onRequest } = require('firebase-functions/v2/https');
const cors = require('cors')({ origin: true });

const { requireAuth } = require('./src/shared/auth');
const { getAccessibleRoute } = require('./src/routes/routing');
const { submitReport } = require('./src/reports/report');
const { getRutaVivaScore } = require('./src/ruta-viva/prediction');
const { handleVoiceQuery } = require('./src/voice/conversation');
const { startCrisis, updateCrisis, resolveCrisis } = require('./src/crisis/crisis');

function wrap(handler) {
  return onRequest({ region: 'us-central1' }, (req, res) => {
    cors(req, res, async () => {
      try {
        await handler(req, res);
      } catch (err) {
        console.error(`[${req.path}]`, err);
        res.status(err.statusCode || 500).json({ error: err.message });
      }
    });
  });
}

// ── Config pública — entrega las creds anon al browser sin hardcodearlas ─────
// Solo expone la ANON key (segura por RLS). Nunca incluir SERVICE_KEY aquí.
exports.config = wrap(async (req, res) => {
  res.json({
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
    mapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  });
});

// ── Fase 2: ruteo accesible ───────────────────────────────────────────────────
exports.routingAccessible = wrap(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  // Ruteo es info pública — no requiere auth.
  const { origin, destination, userProfile, arrivalTime } = req.body || {};
  if (!origin || !destination || !userProfile) {
    return res.status(400).json({ error: 'origin, destination y userProfile son requeridos' });
  }
  const result = await getAccessibleRoute(origin, destination, userProfile, arrivalTime);
  res.json(result);
});

// ── Fase 3: Puente Ciudadano ──────────────────────────────────────────────────
exports.reportSubmit = wrap(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!(await requireAuth(req, res))) return;
  const { lat, lng, photoUrl, weather } = req.body || {};
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !photoUrl) {
    return res.status(400).json({ error: 'lat, lng y photoUrl requeridos' });
  }
  const result = await submitReport({ uid: req.uid, lat, lng, photoUrl, weather });
  res.json(result);
});

// ── Fase 4: Ruta Viva ─────────────────────────────────────────────────────────
exports.rutaVivaScore = wrap(async (req, res) => {
  if (req.method !== 'GET') return res.status(405).json({ error: 'GET only' });
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  const arrivalTime = req.query.arrivalTime;
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !arrivalTime) {
    return res.status(400).json({ error: 'lat, lng y arrivalTime requeridos' });
  }
  const result = await getRutaVivaScore(lat, lng, arrivalTime);
  res.json(result);
});

// ── Fase 5: Navegador Sin Pantalla ────────────────────────────────────────────
exports.voiceQuery = wrap(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!(await requireAuth(req, res))) return;
  const { userText, origin, userProfile } = req.body || {};
  if (!userText) return res.status(400).json({ error: 'userText requerido' });
  const result = await handleVoiceQuery({ uid: req.uid, userText, origin, userProfile });
  res.json(result);
});

// ── Fase 6: Modo Crisis ───────────────────────────────────────────────────────
exports.crisisStart = wrap(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!(await requireAuth(req, res))) return;
  const { lat, lng } = req.body || {};
  const result = await startCrisis({ uid: req.uid, lat, lng });
  res.status(201).json(result);
});

exports.crisisUpdate = wrap(async (req, res) => {
  if (req.method !== 'PUT' && req.method !== 'POST') {
    return res.status(405).json({ error: 'PUT only' });
  }
  if (!(await requireAuth(req, res))) return;
  const { sessionId, lat, lng } = req.body || {};
  if (!sessionId) return res.status(400).json({ error: 'sessionId requerido' });
  const result = await updateCrisis({ uid: req.uid, sessionId, lat, lng });
  res.json(result);
});

exports.crisisResolve = wrap(async (req, res) => {
  if (req.method !== 'DELETE' && req.method !== 'POST') {
    return res.status(405).json({ error: 'DELETE only' });
  }
  if (!(await requireAuth(req, res))) return;
  const { sessionId } = req.body || {};
  if (!sessionId) return res.status(400).json({ error: 'sessionId requerido' });
  const result = await resolveCrisis({ uid: req.uid, sessionId });
  res.json(result);
});
