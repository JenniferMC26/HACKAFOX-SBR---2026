// Inicializa el cliente Supabase (service_role) y el de BigQuery una sola vez
// por proceso. Cualquier módulo que necesite supabase / bigquery debe importar
// de aquí — nunca crear su propio createClient().

const { createClient } = require('@supabase/supabase-js');
const { BigQuery } = require('@google-cloud/bigquery');

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

const bigquery = new BigQuery({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
const BQ_DATASET = process.env.BIGQUERY_DATASET || 'paso';

module.exports = {
  supabase,
  bigquery,
  BQ_DATASET,
};
