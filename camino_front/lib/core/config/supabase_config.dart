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
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhZ3JvaWZjZXBjeGh6ZXNlcmRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMDc0OTYsImV4cCI6MjA5NTU4MzQ5Nn0.Wbq5mAnXN977QehJIGZhvsBmCD545SUCl9hdysm_ADI';

  // Groq API — Groq Cloud → API Keys
  static const groqApiKey = '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';

  // Google Maps SDK (Android + Web) — Google Cloud Console → Credentials
  static const googleMapsApiKey = 'AIzaSyCjd1xBS1fJqOWOCyQTzCKL8wykQi9PaNI';

  // Google Places API — key separada, solo con Places API habilitada
  // Reemplaza este valor con tu nueva key de Places
  static const placesApiKey = 'AIzaSyBmj2c3nXr0mg_cdD3bpNY0xPzr5h4w-r0';
}
