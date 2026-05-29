// Inserta los nodos estimados en public.accessibility_nodes y los patrones
// temporales para Ruta Viva en public.temporal_patterns.
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

// ── 1. Nodos estimados ──────────────────────────────────────────────────────
async function seedNodes() {
  const nodes = JSON.parse(
    fs.readFileSync(path.resolve(__dirname, 'estimated-nodes.json'), 'utf8')
  );
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
  if (error) throw new Error(`accessibility_nodes: ${error.message}`);
  console.log(`OK — ${data.length} nodos upserted en accessibility_nodes`);
}

// ── 2. Patrones temporales (Ruta Viva) ──────────────────────────────────────
// Each (POI × hour × dow) slot gets REPS records at offsets within ~20 m so
// that ruta_viva_history() always returns COUNT >= REPS regardless of whether
// neighbouring nodes happen to be within the 200 m radius.
// REPS = 4 guarantees data_points >= RUTA_VIVA_MIN_DATA_POINTS (3).
const TEMPORAL_REPS = 4;
const TEMPORAL_OFFSET = 0.00018; // ≈ 20 m

const OFFSETS = [
  [0, 0],
  [TEMPORAL_OFFSET, 0],
  [0, TEMPORAL_OFFSET],
  [-TEMPORAL_OFFSET, 0],
];

function generateTemporalPatterns() {
  // POIs alineados con los nodos estimados para que las queries coincidan.
  const POIS = [
    { name: 'mercado_hidalgo', lat: 32.5305, lng: -117.0349 }, // node_mercado_hidalgo_acceso
    { name: 'av_revolucion',   lat: 32.5320, lng: -117.0372 }, // node_revolucion_av_norte
    { name: 'hospital_general',lat: 32.5189, lng: -117.0289 }, // node_hospital_general_estacion
    { name: 'imss_zonario',    lat: 32.5248, lng: -117.0284 }, // node_imss_zonario_banqueta
    { name: 'cecut',           lat: 32.5251, lng: -117.0072 }, // node_cecut_entrada
    { name: 'centro_norte',    lat: 32.5350, lng: -117.0300 }, // node_centro_comunitario_norte
  ];

  function baseScore(name, dow, hour) {
    // Default: mostly accessible.
    let score = 0.80;
    // Rush-hour degradation for all POIs (8-9 am, 6-7 pm).
    if ((hour >= 8 && hour <= 9) || (hour >= 18 && hour <= 19)) score -= 0.12;
    // POI-specific patterns.
    if (name === 'mercado_hidalgo') {
      if (dow === 2 && hour >= 10 && hour <= 14) score = 0.25;      // miércoles tianguis
      else if (dow === 5 && hour >= 8 && hour <= 16) score = 0.35;  // sábado mercado
      else if (hour >= 10 && hour <= 12) score -= 0.15;             // vendedores diario
    }
    if (name === 'av_revolucion' && (dow === 4 || dow === 5) && hour >= 20 && hour <= 23) {
      score = 0.25; // viernes/sábado noche — aglomeración
    }
    if (name === 'hospital_general' && dow >= 1 && dow <= 4 && hour >= 9 && hour <= 13) {
      score -= 0.10; // horario de consultas
    }
    if (name === 'imss_zonario' && dow >= 1 && dow <= 4 && hour >= 8 && hour <= 13) {
      score -= 0.12;
    }
    // Madrugada siempre accesible.
    if (hour <= 5) score = Math.min(score + 0.15, 0.95);
    return Math.round(Math.min(0.98, Math.max(0.05, score)) * 100) / 100;
  }

  function eventFlag(name, dow, hour) {
    if (name === 'mercado_hidalgo' && dow === 2 && hour >= 10 && hour <= 14) return true;
    if (name === 'mercado_hidalgo' && dow === 5 && hour >= 8 && hour <= 16) return true;
    if (name === 'av_revolucion' && (dow === 4 || dow === 5) && hour >= 20 && hour <= 23) return true;
    return false;
  }

  const rows = [];
  for (const poi of POIS) {
    for (let dow = 0; dow < 7; dow++) {
      for (let hour = 0; hour < 24; hour++) {
        const score = baseScore(poi.name, dow, hour);
        const isEvent = eventFlag(poi.name, dow, hour);
        for (let r = 0; r < TEMPORAL_REPS; r++) {
          const [dLat, dLng] = OFFSETS[r];
          // Add tiny noise so AVG isn't perfectly flat.
          const noise = (Math.random() - 0.5) * 0.04;
          rows.push({
            lat: poi.lat + dLat,
            lng: poi.lng + dLng,
            hour_of_day: hour,
            day_of_week: dow,
            accessibility_score: Math.min(0.98, Math.max(0.05,
              Math.round((score + noise) * 100) / 100)),
            event_flag: isEvent,
            report_count: Math.max(0, Math.round((1 - score) * 10)),
          });
        }
      }
    }
  }
  return rows;
}

async function seedTemporalPatterns() {
  // Delete existing rows to avoid duplicates on re-runs.
  const { error: delErr } = await supabase.from('temporal_patterns').delete().neq('id', '');
  if (delErr && !delErr.message.includes('No rows')) {
    console.warn(`temporal_patterns delete: ${delErr.message}`);
  }
  const rows = generateTemporalPatterns();
  // Insert in chunks of 200 to stay within Supabase's per-request payload limit.
  const CHUNK = 200;
  let inserted = 0;
  for (let i = 0; i < rows.length; i += CHUNK) {
    const chunk = rows.slice(i, i + CHUNK);
    const { error } = await supabase.from('temporal_patterns').insert(chunk);
    if (error) throw new Error(`temporal_patterns batch ${i}: ${error.message}`);
    inserted += chunk.length;
  }
  const total = `${6} POIs × 24h × 7d × ${TEMPORAL_REPS} reps = ${rows.length} filas esperadas`;
  console.log(`OK — ${inserted} patrones temporales en temporal_patterns (${total})`);
}

(async () => {
  try {
    await seedNodes();
    await seedTemporalPatterns();
    process.exit(0);
  } catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
  }
})();
