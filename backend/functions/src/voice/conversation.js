// Navegador Sin Pantalla — interpreta lenguaje natural (intent → ruta o info).
//
// Llama dos veces a Gemini:
//   1. Para extraer intent + destino (Places resuelve coords si es navegación).
//   2. Para convertir la ruta técnica en instrucciones de voz en español.
//
// En modo MOCK (sin GEMINI_API_KEY) se infiere intent con keywords simples y se
// resuelve el destino a coordenadas hardcoded de POIs de Tijuana. Útil para
// validar el pipeline end-to-end contra el emulador.

const { getAccessibleRoute } = require('../routes/routing');

const USE_MOCK_GEMINI = !process.env.GEMINI_API_KEY;
const USE_MOCK_PLACES = !process.env.GOOGLE_MAPS_API_KEY;

const POIS_FALLBACK = {
  imss:               { lat: 32.5248, lng: -117.0284, name: 'IMSS Zona Río' },
  hospital:           { lat: 32.5189, lng: -117.0289, name: 'Hospital General de Tijuana' },
  cecut:              { lat: 32.5251, lng: -117.0072, name: 'CECUT' },
  mercado:            { lat: 32.5305, lng: -117.0349, name: 'Mercado Hidalgo' },
  catedral:           { lat: 32.5307, lng: -117.0349, name: 'Catedral de Tijuana' },
  revolucion:         { lat: 32.5320, lng: -117.0372, name: 'Av. Revolución' },
  'centro comunitario': { lat: 32.5350, lng: -117.0300, name: 'Centro Comunitario Norte' },
};

function mockInterpret(userText) {
  const t = userText.toLowerCase();
  if (/(donde|cómo llego|llevame|llévame|ruta|ir|ir a|navega)/.test(t)) {
    for (const [k, place] of Object.entries(POIS_FALLBACK)) {
      if (t.includes(k)) return { intent: 'navigate', destinationName: place.name, destination: place };
    }
    return { intent: 'navigate', destinationName: null, destination: null };
  }
  if (/(reportar|hay un|bloqueado|rampa|barrera)/.test(t)) {
    return { intent: 'report', destinationName: null, destination: null };
  }
  return { intent: 'info', destinationName: null, destination: null };
}

function mockVoiceFromRoute(route, destName) {
  if (!route) return 'No pude calcular la ruta. ¿Puedes repetir el destino?';
  const dist = route.distanceMeters;
  const min = Math.max(1, Math.round(route.durationSeconds / 60));
  const warn = (route.warnings || []).filter((w) => w.severity >= 5);
  let msg = `Vamos a ${destName || 'tu destino'}. Son ${dist} metros, aproximadamente ${min} minutos caminando.`;
  if (warn.length > 0) {
    msg += ` Atención: hay ${warn.length} obstáculo${warn.length > 1 ? 's' : ''} reportado${warn.length > 1 ? 's' : ''} en el camino.`;
  } else {
    msg += ' El camino está despejado según los reportes recientes.';
  }
  return msg;
}

async function geminiInterpret(userText) {
  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  const prompt = `Eres asistente de movilidad accesible en Tijuana. Devuelve SOLO un JSON:
{ "intent": "navigate|report|info|other", "destinationName": "string|null" }
Texto del usuario: "${userText}"`;
  const result = await model.generateContent(prompt);
  const text = result.response.text().replace(/```json|```/g, '').trim();
  return JSON.parse(text);
}

async function placesResolve(name) {
  if (USE_MOCK_PLACES || !name) {
    const key = name && name.toLowerCase();
    return POIS_FALLBACK[key] || null;
  }
  const url = 'https://places.googleapis.com/v1/places:searchText';
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
      'X-Goog-FieldMask': 'places.displayName,places.location',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ textQuery: `${name} Tijuana`, languageCode: 'es' }),
  });
  if (!res.ok) throw new Error(`Places ${res.status}`);
  const data = await res.json();
  const p = data.places && data.places[0];
  if (!p) return null;
  return { lat: p.location.latitude, lng: p.location.longitude, name: p.displayName.text };
}

async function geminiVoiceFromRoute(route, destName) {
  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  const prompt = `Convierte esta ruta accesible en una instrucción hablada en español neutro, máximo 3 oraciones. Sé claro sobre obstáculos.
Destino: ${destName}
Distancia: ${route.distanceMeters} m
Duración: ${Math.round(route.durationSeconds / 60)} min
Score accesibilidad: ${route.accessibilityScore}/10
Warnings: ${JSON.stringify(route.warnings)}`;
  const result = await model.generateContent(prompt);
  return result.response.text().trim();
}

async function handleVoiceQuery({ uid, userText, origin, userProfile }) {
  const interpret = USE_MOCK_GEMINI ? mockInterpret(userText) : await geminiInterpret(userText);

  if (interpret.intent !== 'navigate') {
    return { intent: interpret.intent, voiceResponse: `Entendido: ${interpret.intent}. Por ahora solo puedo navegar.` };
  }

  let destination = interpret.destination;
  if (!destination && interpret.destinationName) {
    destination = await placesResolve(interpret.destinationName);
  }
  if (!destination) {
    return { intent: 'navigate', voiceResponse: 'No encontré ese destino. ¿Puedes decirlo de otra forma?' };
  }
  if (!origin) {
    return { intent: 'navigate', voiceResponse: 'Necesito tu ubicación actual para calcular la ruta.' };
  }

  const routing = await getAccessibleRoute(origin, destination, userProfile || 'wheelchair');
  const voiceResponse = USE_MOCK_GEMINI
    ? mockVoiceFromRoute(routing.route, destination.name)
    : await geminiVoiceFromRoute(routing.route, destination.name);

  return {
    intent: 'navigate',
    destination,
    route: routing.route,
    voiceResponse,
  };
}

module.exports = { handleVoiceQuery };
