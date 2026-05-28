// Puente Ciudadano — recibe un reporte (con foto ya subida a Storage), lo analiza
// con Gemini, actualiza /accessibility_layer y dispara escritura a BigQuery +
// ticket cívico si severity >= 7.

const { randomUUID } = require('crypto');
const { db, bigquery, BQ_DATASET } = require('../shared/clients');
const { findNearestNode, upsertNode } = require('../shared/nodeUtils');
const {
  severityToScore,
  REPORT_NEARBY_RADIUS_METERS,
  GEMINI_MIN_CONFIDENCE,
  TICKET_SEVERITY_THRESHOLD,
  MAX_REPORTS_PER_HOUR,
  TJ_BOUNDS,
} = require('../shared/constants');
const { analyzeBarrierPhoto } = require('./geminiVision');

const USE_MOCK_BQ = !process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.GCLOUD_PROJECT_PROD;

function validatePhotoUrl(photoUrl) {
  const bucket = process.env.STORAGE_BUCKET || 'paso.firebasestorage.app';
  // Acepta URLs reales del bucket + URLs del emulador local.
  const allowed = [
    `https://firebasestorage.googleapis.com/v0/b/${bucket}`,
    `http://localhost:9199/v0/b/${bucket}`,
    `http://emulator:9199/v0/b/${bucket}`,
  ];
  return allowed.some((p) => photoUrl.startsWith(p));
}

async function checkRateLimit(uid) {
  const hourKey = new Date().toISOString().slice(0, 13); // "2026-05-28T10"
  const ref = db.ref(`users/${uid}/reportCount/${hourKey}`);
  const result = await ref.transaction((n) => (n || 0) + 1);
  return (result.snapshot.val() || 0) <= MAX_REPORTS_PER_HOUR;
}

async function nextTicketId() {
  const year = new Date().getFullYear();
  const result = await db.ref('counters/ticketSeq').transaction((n) => (n || 0) + 1);
  const seq = String(result.snapshot.val() || 1).padStart(4, '0');
  return `PASO-${year}-${seq}`;
}

async function writeToBigQuery(table, row) {
  if (USE_MOCK_BQ) {
    console.log(`[mock-bq] insert ${BQ_DATASET}.${table}:`, JSON.stringify(row));
    return;
  }
  try {
    await bigquery.dataset(BQ_DATASET).table(table).insert([row]);
  } catch (err) {
    console.error(`BigQuery insert ${table} falló:`, err.message);
  }
}

async function submitReport({ uid, lat, lng, photoUrl, weather }) {
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    lat < TJ_BOUNDS.latMin ||
    lat > TJ_BOUNDS.latMax ||
    lng < TJ_BOUNDS.lngMin ||
    lng > TJ_BOUNDS.lngMax
  ) {
    const err = new Error('Coordenadas fuera del bounding box de Tijuana');
    err.statusCode = 400;
    throw err;
  }
  if (!validatePhotoUrl(photoUrl)) {
    const err = new Error('photoUrl no pertenece al bucket autorizado');
    err.statusCode = 400;
    throw err;
  }

  const withinLimit = await checkRateLimit(uid);
  if (!withinLimit) {
    const err = new Error('Límite de reportes por hora alcanzado');
    err.statusCode = 429;
    throw err;
  }

  const analysis = await analyzeBarrierPhoto(photoUrl);
  const score = severityToScore(analysis.severity);
  const requiresHumanReview = analysis.confidence < GEMINI_MIN_CONFIDENCE;

  const reportId = randomUUID();
  const now = new Date();
  const nowIso = now.toISOString();

  // 1. Persistir el reporte
  const reportData = {
    userId: uid,
    lat,
    lng,
    photoUrl,
    geminiAnalysis: analysis,
    requiresHumanReview,
    status: 'pending',
    createdAt: nowIso,
  };

  // 2. Upsert en /accessibility_layer (nodo cercano o nuevo)
  const nearest = await findNearestNode(lat, lng, REPORT_NEARBY_RADIUS_METERS);
  const nodeId = nearest ? nearest.nodeId : `node_report_${reportId.slice(0, 8)}`;

  const previousReportCount = nearest ? (nearest.reportCount || 0) : 0;
  await upsertNode(nodeId, {
    lat: nearest ? nearest.lat : lat,
    lng: nearest ? nearest.lng : lng,
    type: nearest ? nearest.type : 'sidewalk',
    accessible: score >= 5,
    score,
    source: 'field_verified',
    barrierType: analysis.barrierType === 'none' ? null : analysis.barrierType,
    photoUrl,
    geminiAnalysis: analysis,
    lastReported: nowIso,
    reportCount: previousReportCount + 1,
  });

  // 3. Ticket cívico si severity alto
  let ticketId = null;
  if (analysis.severity >= TICKET_SEVERITY_THRESHOLD) {
    ticketId = await nextTicketId();
    writeToBigQuery('civic_tickets', {
      ticket_id: ticketId,
      report_id: reportId,
      lat,
      lng,
      barrier_type: analysis.barrierType,
      severity: analysis.severity,
      photo_url: photoUrl,
      gemini_description: analysis.description,
      affected_users_estimate: (analysis.affectedProfiles || []).length * 100,
      created_at: nowIso,
      status: 'open',
    });
  }

  reportData.ticketId = ticketId;
  await db.ref(`reports/${reportId}`).set(reportData);

  // 4. Espejo en BigQuery (fire and forget)
  writeToBigQuery('accessibility_reports', {
    report_id: reportId,
    user_id: uid,
    lat,
    lng,
    barrier_type: analysis.barrierType,
    severity: analysis.severity,
    hour_of_day: now.getUTCHours(),
    day_of_week: (now.getUTCDay() + 6) % 7, // 0 = lunes
    weather_condition: weather || null,
    reported_at: nowIso,
  });

  return {
    reportId,
    ticketId,
    nodeId,
    score,
    requiresHumanReview,
    analysis,
  };
}

module.exports = { submitReport };
