// Inicializa Firebase Admin y BigQuery una sola vez por proceso. Cualquier
// módulo que necesite db / bigquery debe importar de aquí — nunca llamar
// admin.initializeApp() por su cuenta.

const admin = require('firebase-admin');
const { BigQuery } = require('@google-cloud/bigquery');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();
const auth = admin.auth();
const storage = admin.storage();

// `paso` es el dataset por defecto — coincide con seed/queries.sql.
const bigquery = new BigQuery();
const BQ_DATASET = process.env.BIGQUERY_DATASET || 'paso';

module.exports = {
  admin,
  db,
  auth,
  storage,
  bigquery,
  BQ_DATASET,
};
