// Inserta 3 usuarios de prueba en /users.
//
// Uso:
//   docker compose run --rm seed node seed/users-seed.js
//
// Los uids son fijos para que las pruebas locales sean reproducibles. En producción
// el uid lo genera Firebase Auth — estos uids no chocan porque empiezan con "test_".

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || 'paso';
const USING_EMULATOR = !!process.env.FIREBASE_DATABASE_EMULATOR_HOST;

function initFirebase() {
  if (USING_EMULATOR) {
    admin.initializeApp({
      projectId: PROJECT_ID,
      databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}/?ns=${PROJECT_ID}-default-rtdb`,
    });
    console.log(`[emulator] RTDB -> ${process.env.FIREBASE_DATABASE_EMULATOR_HOST}`);
    return;
  }
  const keyPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error('serviceAccountKey.json no encontrado y no estás contra el emulador. Abortando.');
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });
  console.log(`[prod] RTDB -> ${process.env.FIREBASE_DATABASE_URL}`);
}

const users = {
  test_user_wheelchair: {
    profile: {
      displayName: 'Test — Silla de ruedas',
      mobilityType: 'wheelchair',
      avoidSteps: true,
      avoidSlopes: true,
      slopeMaxPercent: 6,
      emergencyContacts: ['test_user_contact'],
    },
  },
  test_user_elderly: {
    profile: {
      displayName: 'Test — Adulto mayor',
      mobilityType: 'elderly',
      avoidSteps: true,
      avoidSlopes: false,
      slopeMaxPercent: 10,
      emergencyContacts: ['test_user_contact'],
    },
  },
  test_user_contact: {
    profile: {
      displayName: 'Test — Contacto de emergencia',
      mobilityType: 'none',
      avoidSteps: false,
      avoidSlopes: false,
      slopeMaxPercent: 100,
      emergencyContacts: [],
    },
  },
};

(async () => {
  try {
    initFirebase();
    await admin.database().ref('users').update(users);
    console.log(`OK — ${Object.keys(users).length} usuarios de prueba insertados en /users`);
    process.exit(0);
  } catch (err) {
    console.error('ERROR:', err);
    process.exit(1);
  }
})();
