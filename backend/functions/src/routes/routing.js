// Motor de ruteo accesible.
//
// Pipeline:
//   1. Pedir ruta base a Google Routes API (o MOCK si no hay key).
//   2. Decodificar polyline → bounding box.
//   3. Buscar nodos de /accessibility_layer dentro del bbox.
//   4. Calcular score promedio ponderado por perfil + warnings.
//   5. Si arrivalTime presente → llamar getRutaVivaScore() y mezclar.
//
// El MOCK activa cuando GOOGLE_MAPS_API_KEY está vacío. Genera una "ruta" recta
// interpolada (10 puntos) entre origen y destino. Permite probar el pipeline
// completo contra el emulador sin tocar prod.

const { findNodesInBoundingBox, distanceMeters } = require('../shared/nodeUtils');
const { THRESHOLDS, TJ_BOUNDS } = require('../shared/constants');
const { encode, decode } = require('../shared/polyline');

const ROUTES_API_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const USE_MOCK_ROUTES = !process.env.GOOGLE_MAPS_API_KEY;

const PROFILE_RULES = {
  wheelchair: { minScore: THRESHOLDS.wheelchair, avoidBarrierTypes: ['broken_ramp', 'missing_ramp', 'no_curb_cut'] },
  elderly:    { minScore: THRESHOLDS.elderly,    avoidBarrierTypes: ['missing_ramp'] },
  cane:       { minScore: THRESHOLDS.cane,       avoidBarrierTypes: [] },
  stroller:   { minScore: THRESHOLDS.stroller,   avoidBarrierTypes: [] },
  none:       { minScore: THRESHOLDS.none,       avoidBarrierTypes: [] },
};

function isValidCoord(c) {
  return (
    c && Number.isFinite(c.lat) && Number.isFinite(c.lng) &&
    c.lat >= TJ_BOUNDS.latMin && c.lat <= TJ_BOUNDS.latMax &&
    c.lng >= TJ_BOUNDS.lngMin && c.lng <= TJ_BOUNDS.lngMax
  );
}

async function fetchMapsRoute(origin, destination) {
  const res = await fetch(ROUTES_API_URL, {
    method: 'POST',
    headers: {
      'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
      'X-Goog-FieldMask': 'routes.encodedPolyline,routes.distanceMeters,routes.duration',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      origin: { location: { latLng: origin } },
      destination: { location: { latLng: destination } },
      travelMode: 'WALK',
      computeAlternativeRoutes: false,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Routes API ${res.status}: ${text}`);
  }
  const data = await res.json();
  const r = data.routes && data.routes[0];
  if (!r) throw new Error('Routes API no devolvió ruta');
  return {
    encodedPolyline: r.encodedPolyline.encodedPolyline,
    distanceMeters: r.distanceMeters,
    durationSeconds: parseInt(r.duration, 10),
  };
}

function mockRoute(origin, destination) {
  // 10 puntos interpolados linealmente entre origen y destino.
  const points = [];
  const N = 10;
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    points.push({
      lat: origin.lat + (destination.lat - origin.lat) * t,
      lng: origin.lng + (destination.lng - origin.lng) * t,
    });
  }
  const distance = Math.round(distanceMeters(origin.lat, origin.lng, destination.lat, destination.lng));
  return {
    encodedPolyline: encode(points),
    distanceMeters: distance,
    durationSeconds: Math.round(distance / 1.4), // ≈ 1.4 m/s caminando
    _mock: true,
  };
}

function boundingBoxFromPolyline(encodedPolyline, marginDeg = 0.0008) {
  const pts = decode(encodedPolyline);
  let latMin = Infinity, latMax = -Infinity, lngMin = Infinity, lngMax = -Infinity;
  for (const p of pts) {
    if (p.lat < latMin) latMin = p.lat;
    if (p.lat > latMax) latMax = p.lat;
    if (p.lng < lngMin) lngMin = p.lng;
    if (p.lng > lngMax) lngMax = p.lng;
  }
  return {
    latMin: latMin - marginDeg,
    latMax: latMax + marginDeg,
    lngMin: lngMin - marginDeg,
    lngMax: lngMax + marginDeg,
  };
}

function scoreRoute(nodes, rules) {
  if (nodes.length === 0) {
    return {
      score: 5.0,
      warnings: [{ type: 'unvalidated', severity: 0, message: 'Tramo sin validación reciente' }],
    };
  }
  let total = 0;
  let totalWeight = 0;
  const warnings = [];
  for (const node of nodes) {
    // Field-verified pesa más que estimated.
    const weight = node.source === 'field_verified' ? 1.5 : 1.0;
    total += node.score * weight;
    totalWeight += weight;

    const triggersBarrier = node.barrierType && rules.avoidBarrierTypes.includes(node.barrierType);
    if (node.score < rules.minScore || triggersBarrier) {
      warnings.push({
        type: node.barrierType || 'low_score',
        lat: node.lat,
        lng: node.lng,
        severity: Math.max(0, 10 - node.score),
        nodeId: node.nodeId,
        source: node.source,
        message: triggersBarrier
          ? `Obstáculo incompatible con perfil: ${node.barrierType}`
          : `Score bajo (${node.score}/10)`,
      });
    }
  }
  return {
    score: Math.round((total / totalWeight) * 10) / 10,
    warnings,
  };
}

async function getAccessibleRoute(origin, destination, userProfile, arrivalTime) {
  if (!isValidCoord(origin) || !isValidCoord(destination)) {
    const err = new Error('origin/destination fuera del bounding box de Tijuana');
    err.statusCode = 400;
    throw err;
  }
  const rules = PROFILE_RULES[userProfile] || PROFILE_RULES.none;

  const baseRoute = USE_MOCK_ROUTES
    ? mockRoute(origin, destination)
    : await fetchMapsRoute(origin, destination);

  const bbox = boundingBoxFromPolyline(baseRoute.encodedPolyline);
  const nodes = await findNodesInBoundingBox(bbox);
  const { score, warnings } = scoreRoute(nodes, rules);

  let rutaVivaAdjustment = null;
  if (arrivalTime) {
    try {
      const { getRutaVivaScore } = require('../ruta-viva/prediction');
      const midLat = (origin.lat + destination.lat) / 2;
      const midLng = (origin.lng + destination.lng) / 2;
      rutaVivaAdjustment = await getRutaVivaScore(midLat, midLng, arrivalTime);
    } catch (err) {
      rutaVivaAdjustment = { applied: false, reason: `Ruta Viva no disponible: ${err.message}` };
    }
  }

  return {
    route: {
      encodedPolyline: baseRoute.encodedPolyline,
      distanceMeters: baseRoute.distanceMeters,
      durationSeconds: baseRoute.durationSeconds,
      accessibilityScore: score,
      warnings,
      nodesEvaluated: nodes.length,
      mock: !!baseRoute._mock,
    },
    rutaVivaAdjustment,
    alternativeRoute: null,
  };
}

module.exports = { getAccessibleRoute };
