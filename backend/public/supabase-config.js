// Config pública del SDK cliente Supabase.
// SOLO la SUPABASE_ANON_KEY va aquí — nunca la service_role.
// Las Cloud Functions se redirigen al emulador local en localhost.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

// Project shared del equipo (ajustar si cambia).
const SUPABASE_URL = 'https://xagroifcepcxhzeserda.supabase.co';
// ⚠️ Pegar aquí la ANON KEY (no la service_role). La encuentras en
//    Supabase Dashboard → Project Settings → API → Project API keys → anon public.
const SUPABASE_ANON_KEY = '';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

export const FUNCTIONS_BASE =
  location.hostname === 'localhost'
    ? 'http://localhost:5001/paso/us-central1'
    : 'https://us-central1-paso.cloudfunctions.net';

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
