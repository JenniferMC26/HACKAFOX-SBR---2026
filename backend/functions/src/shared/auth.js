// Middleware: extrae y verifica el idToken del header Authorization.
// Pone req.uid si el token es válido. Devuelve 401 si no.
//
// En el emulador, `admin.auth()` auto-detecta FIREBASE_AUTH_EMULATOR_HOST y valida
// contra el emulador, así que esto funciona igual local y en prod.
//
// Para pruebas rápidas sin browser-auth, setear SKIP_AUTH=true en `.env` y se
// usa "test_user_anonymous" como uid. NUNCA en producción.

const { auth } = require('./clients');

async function requireAuth(req, res) {
  if (process.env.SKIP_AUTH === 'true') {
    req.uid = req.header('X-Test-Uid') || 'test_user_anonymous';
    return true;
  }

  const header = req.header('Authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    res.status(401).json({ error: 'Falta header Authorization: Bearer <idToken>' });
    return false;
  }

  try {
    const decoded = await auth.verifyIdToken(match[1]);
    req.uid = decoded.uid;
    return true;
  } catch (err) {
    res.status(401).json({ error: 'idToken inválido', detail: err.message });
    return false;
  }
}

module.exports = { requireAuth };
