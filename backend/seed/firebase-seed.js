// Inserta los nodos estimados en /accessibility_layer.
//
// Uso:
//   docker compose run --rm seed node seed/firebase-seed.js
//
// Detecta automáticamente si corre contra el emulador (FIREBASE_DATABASE_EMULATOR_HOST
// está seteado por docker-compose). En ese caso no necesita serviceAccountKey.json.
// Cada nodo se persiste con geohash precision 7 — requerido por findNodesInBoundingBox.

const admin = require('firebase-admin');
const ngeohash = require('ngeohash');
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

async function seedEstimatedNodes() {
  const nodes = require('./estimated-nodes.json');
  const db = admin.database();
  const ref = db.ref('accessibility_layer');
  const now = new Date().toISOString();

  const updates = {};
  for (const n of nodes) {
    updates[n.nodeId] = {
      lat: n.lat,
      lng: n.lng,
      type: n.type,
      accessible: n.score >= 5,
      score: n.score,
      geohash: ngeohash.encode(n.lat, n.lng, 7),
      source: 'estimated',
      verifiedBy: null,
      verifiedAt: null,
      photoUrl: null,
      geminiAnalysis: null,
      barrierType: n.barrierType,
      lastReported: now,
      reportCount: 0,
    };
  }

  await ref.update(updates);
  console.log(`OK — ${nodes.length} nodos insertados en /accessibility_layer`);
}

(async () => {
  try {
    initFirebase();
    await seedEstimatedNodes();
    process.exit(0);
  } catch (err) {
    console.error('ERROR:', err);
    process.exit(1);
  }
})();
