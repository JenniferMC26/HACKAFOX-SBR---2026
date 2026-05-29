// Config pública del SDK cliente Supabase.
// Ya no depende del emulador de Firebase Functions — lee directamente de config.js.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_MAPS_API_KEY } from './config.js';

export { GOOGLE_MAPS_API_KEY };

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
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
