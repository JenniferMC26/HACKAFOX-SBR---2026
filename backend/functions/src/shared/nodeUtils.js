// Operaciones sobre /accessibility_layer. RTDB no tiene queries geoespaciales,
// así que filtramos por rango de geohash y refinamos en memoria.

const ngeohash = require('ngeohash');
const { db } = require('./clients');
const { GEOHASH_PRECISION } = require('./constants');

const EARTH_RADIUS_M = 6_371_000;

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

// Haversine entre dos puntos en metros.
function distanceMeters(lat1, lng1, lat2, lng2) {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
}

// Devuelve los geohash prefixes únicos que cubren el bounding box.
// Usamos precision 5 al consultar (más laxo) porque queremos un superset que
// luego filtramos por bbox exacto en memoria.
function geohashesForBounds({ latMin, latMax, lngMin, lngMax }, precision = 5) {
  const sw = ngeohash.encode(latMin, lngMin, precision);
  const ne = ngeohash.encode(latMax, lngMax, precision);
  const seen = new Set([sw, ne]);
  // ngeohash.bboxes devuelve todos los prefixes que tocan el bbox.
  for (const h of ngeohash.bboxes(latMin, lngMin, latMax, lngMax, precision)) {
    seen.add(h);
  }
  return [...seen].sort();
}

// Trae todos los nodos cuyo geohash empieza con alguno de los prefixes que tocan
// el bbox, luego refina filtrando por bounds reales.
async function findNodesInBoundingBox(bounds) {
  const prefixes = geohashesForBounds(bounds);
  const results = [];
  const seenIds = new Set();

  for (const prefix of prefixes) {
    const snap = await db
      .ref('accessibility_layer')
      .orderByChild('geohash')
      .startAt(prefix)
      .endAt(prefix + '')
      .once('value');

    snap.forEach((child) => {
      if (seenIds.has(child.key)) return;
      const v = child.val();
      if (
        v.lat >= bounds.latMin &&
        v.lat <= bounds.latMax &&
        v.lng >= bounds.lngMin &&
        v.lng <= bounds.lngMax
      ) {
        seenIds.add(child.key);
        results.push({ nodeId: child.key, ...v });
      }
    });
  }

  return results;
}

// Encuentra el nodo más cercano dentro de un radio. Devuelve null si ninguno.
async function findNearestNode(lat, lng, radiusMeters) {
  // Bounding box aproximado a partir del radio (1 grado ≈ 111 km).
  const dLat = radiusMeters / 111_000;
  const dLng = radiusMeters / (111_000 * Math.cos(toRad(lat)));
  const candidates = await findNodesInBoundingBox({
    latMin: lat - dLat,
    latMax: lat + dLat,
    lngMin: lng - dLng,
    lngMax: lng + dLng,
  });

  let best = null;
  let bestDist = Infinity;
  for (const node of candidates) {
    const d = distanceMeters(lat, lng, node.lat, node.lng);
    if (d <= radiusMeters && d < bestDist) {
      best = { ...node, distanceMeters: d };
      bestDist = d;
    }
  }
  return best;
}

// Crea o actualiza un nodo, garantizando que el geohash queda persistido.
async function upsertNode(nodeId, nodeData) {
  const withHash = {
    ...nodeData,
    geohash: ngeohash.encode(nodeData.lat, nodeData.lng, GEOHASH_PRECISION),
  };
  await db.ref(`accessibility_layer/${nodeId}`).update(withHash);
  return { nodeId, ...withHash };
}

module.exports = {
  distanceMeters,
  geohashesForBounds,
  findNodesInBoundingBox,
  findNearestNode,
  upsertNode,
};
