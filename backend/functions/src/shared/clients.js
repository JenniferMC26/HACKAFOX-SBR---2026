// Cliente Supabase (service_role) — lazy init.
//
// El emulador de Firebase analiza el código en una fase separada de la carga
// de .env, por eso instanciar createClient() en top-level revienta con
// "supabaseUrl is required". Usamos un Proxy que difiere la inicialización
// hasta el primer uso (cuando las env vars ya están cargadas).

const { createClient } = require('@supabase/supabase-js');

let _client = null;
function getClient() {
  if (_client) return _client;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;
  if (!url || !key) {
    throw new Error('[clients] SUPABASE_URL o SUPABASE_SERVICE_KEY no seteados en .env');
  }
  _client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _client;
}

// Proxy: cualquier acceso a `supabase.xxx` dispara getClient() la primera vez.
const supabase = new Proxy({}, {
  get(_, prop) {
    const c = getClient();
    const v = c[prop];
    return typeof v === 'function' ? v.bind(c) : v;
  },
});

module.exports = { supabase };
