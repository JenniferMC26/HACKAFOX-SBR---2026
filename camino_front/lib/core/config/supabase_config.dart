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

  // Gemini API — Google AI Studio → API Keys
  static const geminiApiKey = 'AQ.Ab8RN6J-S88uiwMgz3olWAcN6yxwAzERh4q76GXHNkGoaxOQsQ';

  // Google Maps — Google Cloud Console → APIs & Services → Credentials
  static const googleMapsApiKey = 'AIzaSyCjd1xBS1fJqOWOCyQTzCKL8wykQi9PaNI';
}
