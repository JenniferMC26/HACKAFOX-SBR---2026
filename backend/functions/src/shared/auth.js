// Middleware: extrae y verifica el JWT de Supabase del header Authorization.
// Pone req.uid si el token es válido. Devuelve 401 si no.
//
// Para pruebas rápidas sin browser-auth, setear SKIP_AUTH=true en `.env` y se
// usa el header X-Test-Uid (o "test_user_anonymous" por defecto). NUNCA en prod.

const { supabase } = require('./clients');

async function requireAuth(req, res) {
  if (process.env.SKIP_AUTH === 'true') {
    req.uid = req.header('X-Test-Uid') || 'test_user_anonymous';
    return true;
  }

  const header = req.header('Authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    res.status(401).json({ error: 'Falta header Authorization: Bearer <token>' });
    return false;
  }

  const { data, error } = await supabase.auth.getUser(match[1]);
  if (error || !data || !data.user) {
    res.status(401).json({ error: 'Token Supabase inválido', detail: error && error.message });
    return false;
  }
  req.uid = data.user.id;
  return true;
}

module.exports = { requireAuth };
