/// Configuracion de Supabase para PASO.
///
/// IMPORTANTE: Reemplaza estos valores con tus claves reales.
/// La anon key se encuentra en: Supabase Dashboard → Settings → API → anon public
///
/// Estas son claves PUBLICAS (anon key), protegidas por RLS.
/// NUNCA incluir service_role key aqui.
class SupabaseConfig {
  SupabaseConfig._();

  // Supabase — Dashboard → Settings → API
  static const supabaseUrl = 'https://xagroifcepcxhzeserda.supabase.co';

  // Legacy anon key (JWT) — Dashboard → Settings → API Keys → Legacy
  static const supabaseAnonKey =
      'PON TU API KEY AQUI';

  // Groq API — Groq Cloud → API Keys
  static const groqApiKey = 'PON TU API KEY AQUI';

  // Google Maps SDK (Android + Web) — Google Cloud Console → Credentials
  static const googleMapsApiKey = 'PON TU API KEY AQUI';

  // Google Places API — key separada, solo con Places API habilitada
  // Reemplaza este valor con tu nueva key de Places
  static const placesApiKey = 'PON TU API KEY AQUI';
}
