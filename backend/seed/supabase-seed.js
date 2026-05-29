// Inserta los nodos estimados en public.accessibility_nodes.
//
// Uso:
//   docker compose run --rm seed node seed/supabase-seed.js
//
// La columna `location` es GENERATED — no se manda, Postgres la calcula.
// Usa service_role para bypassear RLS.

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_KEY;

if (!url || !serviceKey) {
  console.error('Falta SUPABASE_URL o SUPABASE_SERVICE_KEY en .env');
  process.exit(1);
}

const supabase = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

(async () => {
  const nodes = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'estimated-nodes.json'), 'utf8'));
  const rows = nodes.map((n) => ({
    id: n.nodeId,
    lat: n.lat,
    lng: n.lng,
    type: n.type,
    accessible: n.score >= 5,
    score: n.score,
    source: 'estimated',
    barrier_type: n.barrierType,
    last_reported: new Date().toISOString(),
    report_count: 0,
  }));

  const { data, error } = await supabase
    .from('accessibility_nodes')
    .upsert(rows, { onConflict: 'id' })
    .select('id');

  if (error) {
    console.error('ERROR:', error.message);
    process.exit(1);
  }
  console.log(`OK — ${data.length} nodos upserted en accessibility_nodes`);
  process.exit(0);
})();
