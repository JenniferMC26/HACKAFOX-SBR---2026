// Inicializa el cliente Supabase (service_role) una sola vez por proceso.
// Cualquier módulo que necesite supabase debe importar de aquí — nunca crear
// su propio createClient().

const { createClient } = require('@supabase/supabase-js');

if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY) {
  console.warn('[clients] SUPABASE_URL o SUPABASE_SERVICE_KEY no seteados — los endpoints fallarán.');
}

const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_KEY || '',
  {
    auth: { persistSession: false, autoRefreshToken: false },
  }
);

module.exports = { supabase };
