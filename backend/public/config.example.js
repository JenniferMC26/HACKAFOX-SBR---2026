// Copiar este archivo a `config.js` y rellenar con tus propias claves.
// `config.js` está en .gitignore — NO commitear.
//
// Claves públicas — seguras para el browser.
// NUNCA incluir SUPABASE_SERVICE_KEY ni GEMINI_API_KEY aquí
// (Gemini se llama solo desde Cloud Functions).
export const SUPABASE_URL        = 'https://<tu-proyecto>.supabase.co';
export const SUPABASE_ANON_KEY   = '<tu-anon-key>';
export const GOOGLE_MAPS_API_KEY = '<tu-maps-js-api-key>'; // restringir por dominio en GCP
