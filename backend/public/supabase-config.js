// Config pública del SDK cliente Supabase.
//
// La URL y la anon key se obtienen del endpoint /config de las Cloud Functions
// (que las lee de .env). Así no hay nada hardcoded en archivos versionados.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

export const FUNCTIONS_BASE =
  location.hostname === 'localhost'
    ? 'http://localhost:5001/paso/us-central1'
    : 'https://us-central1-paso.cloudfunctions.net';

// Fetch config from backend. Lanza si /config no responde o falta alguna key.
async function loadConfig() {
  const res = await fetch(`${FUNCTIONS_BASE}/config`);
  if (!res.ok) throw new Error(`/config ${res.status}`);
  const cfg = await res.json();
  if (!cfg.supabaseUrl || !cfg.supabaseAnonKey) {
    throw new Error('/config devolvió valores vacíos — revisa SUPABASE_URL / SUPABASE_ANON_KEY en .env');
  }
  return cfg;
}

const cfg = await loadConfig();

export const supabase = createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

// Auth anónimo al cargar — todas las requests llevan el JWT.
export async function ensureAnonSession() {
  const { data } = await supabase.auth.getSession();
  if (data.session) return data.session;
  const res = await supabase.auth.signInAnonymously();
  if (res.error) {
    console.error('signInAnonymously falló — ¿está habilitado en Supabase Auth → Providers?', res.error.message);
  }
  return res.data && res.data.session;
}
