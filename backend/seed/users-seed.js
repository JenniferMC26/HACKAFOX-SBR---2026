// Inserta 3 perfiles de prueba en public.user_profiles.
//
// Uso:
//   docker compose run --rm seed node seed/users-seed.js
//
// Los uids son fijos para que las pruebas locales sean reproducibles. En
// producción el uid lo genera Supabase Auth — estos uids empiezan con "test_"
// y no chocan con uuids reales de Auth.

const { createClient } = require('@supabase/supabase-js');

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_KEY;

if (!url || !serviceKey) {
  console.error('Falta SUPABASE_URL o SUPABASE_SERVICE_KEY en .env');
  process.exit(1);
}

const supabase = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const profiles = [
  {
    uid: 'test_user_wheelchair',
    display_name: 'Test — Silla de ruedas',
    mobility_type: 'wheelchair',
    avoid_steps: true,
    avoid_slopes: true,
    slope_max_percent: 6,
    emergency_contacts: ['test_user_contact'],
  },
  {
    uid: 'test_user_elderly',
    display_name: 'Test — Adulto mayor',
    mobility_type: 'elderly',
    avoid_steps: true,
    avoid_slopes: false,
    slope_max_percent: 10,
    emergency_contacts: ['test_user_contact'],
  },
  {
    uid: 'test_user_contact',
    display_name: 'Test — Contacto de emergencia',
    mobility_type: 'none',
    avoid_steps: false,
    avoid_slopes: false,
    slope_max_percent: 100,
    emergency_contacts: [],
  },
];

(async () => {
  const { data, error } = await supabase
    .from('user_profiles')
    .upsert(profiles, { onConflict: 'uid' })
    .select('uid');
  if (error) {
    console.error('ERROR:', error.message);
    process.exit(1);
  }
  console.log(`OK — ${data.length} perfiles upserted en user_profiles`);
  process.exit(0);
})();
