---
name: vialibretj-navegador-voz
description: >
  Implementa el Navegador Sin Pantalla de VíaLibre TJ: Gemini como motor conversacional
  que interpreta instrucciones de voz ambiguas ("quiero ir al IMSS de aquí cerca"),
  resuelve el destino con Places API y devuelve instrucciones de navegación en texto
  natural en español. Úsalo al implementar POST /voice/query, al ajustar el prompt
  de interpretación geográfica de Gemini, al integrar Places API para resolución de
  destinos vagos, al convertir rutas a instrucciones de voz, o cuando el usuario diga
  "Navegador Sin Pantalla", "entrada por voz", "Gemini conversacional", "instrucciones
  de voz", "interpretar destinos ambiguos" o "navegación sin mirar la pantalla".
---

# VíaLibre TJ — Navegador Sin Pantalla

El Navegador Sin Pantalla diseña la interacción principal para oídos, no para ojos.
Gemini actúa como motor conversacional completo: interpreta frases ambiguas,
resuelve destinos vagos con Places API, y convierte la ruta en instrucciones
de texto natural listas para ser convertidas a voz (TTS).

**Propuesta de valor**: Una persona mayor con bastón no puede sostener el teléfono
y navegar simultáneamente. Este modo es para ellos.

---

## Endpoint

```
POST /voice/query
Content-Type: application/json
```

### Request

```json
{
  "message": "quiero ir al IMSS de aquí cerca",
  "userLat": 32.5027,
  "userLng": -117.0037,
  "userProfile": "wheelchair | elderly | walker",
  "sessionId": "session_xyz",
  "conversationHistory": []
}
```

### Response

```json
{
  "voiceResponse": "Encontré el IMSS Zona Río a 1.2 kilómetros. Tu ruta tiene buena accesibilidad. Hay una advertencia: rampa en mal estado en Boulevard Sánchez Taboada. La ruta alternativa es 200 metros más larga pero sin obstáculos. ¿Cuál prefieres?",
  "intent": "navigate",
  "resolvedDestination": "IMSS Clínica 1 Zona Río",
  "destinationCoords": { "lat": 32.5248, "lng": -117.0284 },
  "route": {
    "encodedPolyline": "...",
    "distanceMeters": 1200,
    "durationSeconds": 960,
    "accessibilityScore": 7.4,
    "warnings": []
  },
  "needsClarification": false,
  "clarificationQuestion": null,
  "sessionId": "session_xyz"
}
```

---

## Implementación — Cloud Function

```javascript
// functions/src/voice/conversation.js
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getAccessibleRoute } = require('../routes/routing');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Prompt de sistema para interpretación geográfica de Tijuana
const GEO_INTERPRETER_PROMPT = `
Eres el asistente de navegación accesible de VíaLibre TJ para Tijuana, Baja California, México.
Los usuarios hablan de forma natural, con referencias locales y frases ambiguas.

Tu trabajo es interpretar la INTENCIÓN DE DESTINO del usuario y estructurarla para que
la app pueda resolverla con Google Places API.

Ejemplos de interpretación:
- "el IMSS de aquí cerca" → Places query: "IMSS Tijuana", intent: navigate
- "quiero ir a la Coahuila" → Places query: "Avenida Coahuila Tijuana", intent: navigate
- "la farmacia de siempre" → no puedes resolver, intent: clarify
- "¿cuánto tiempo tengo?" → no es navegación, intent: info, respuesta: "No entiendo la pregunta en el contexto de navegación"
- "ir al hospital" → Places query: "Hospital General Tijuana", intent: navigate
- "necesito ir al SAT" → Places query: "SAT Servicio de Administración Tributaria Tijuana", intent: navigate
- "la clínica" → intent: clarify (¿cuál clínica?)

Responde ÚNICAMENTE con JSON válido:
{
  "intent": "navigate | clarify | info | cancel",
  "resolvedDestination": "<nombre descriptivo del lugar o null>",
  "placesQuery": "<texto para buscar en Places API, optimizado para Tijuana, o null>",
  "clarificationQuestion": "<pregunta al usuario si intent=clarify, en español, o null>",
  "confidence": <0.0 a 1.0>
}
`;

// Prompt para convertir ruta técnica en instrucciones de voz natural
const ROUTE_TO_VOICE_PROMPT = `
Eres un asistente de navegación amigable para personas mayores y con discapacidad
en Tijuana, México. Convierte los datos técnicos de una ruta en instrucciones
de voz claras, cálidas y concisas en español.

Reglas:
- Usa distancias en metros o "cuadras" (no decimales)
- Menciona puntos de referencia conocidos cuando sea posible (semáforo, farmacia, etc.)
- Si hay advertencias de accesibilidad, menciónalas ANTES de las instrucciones
- Sé empático: el usuario puede tener dificultades de movilidad
- Máximo 3-4 oraciones
- NO uses términos técnicos como "polilinea", "coordenadas" o "nodo"

Ejemplo de salida:
"Tu destino está a 8 minutos caminando. La ruta es mayormente accesible. 
Hay una rampa en mal estado en la Calle 3ra — intenta ir por el lado derecho de la banqueta.
¿Empezamos?"
`;

async function processVoiceQuery({ message, userLat, userLng, userProfile, sessionId, conversationHistory }) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
  
  // Paso 1: Interpretar la intención del usuario
  const interpretResult = await interpretUserIntent(model, message, conversationHistory);
  
  if (interpretResult.intent === 'clarify') {
    return {
      voiceResponse: interpretResult.clarificationQuestion,
      intent: 'clarify',
      resolvedDestination: null,
      destinationCoords: null,
      route: null,
      needsClarification: true,
      clarificationQuestion: interpretResult.clarificationQuestion,
      sessionId
    };
  }
  
  if (interpretResult.intent !== 'navigate' || !interpretResult.placesQuery) {
    return {
      voiceResponse: 'No entendí bien tu destino. ¿Me puedes decir a dónde quieres ir?',
      intent: interpretResult.intent,
      resolvedDestination: null,
      destinationCoords: null,
      route: null,
      needsClarification: true,
      clarificationQuestion: '¿A dónde quieres ir?',
      sessionId
    };
  }
  
  // Paso 2: Resolver coordenadas con Places API
  const placeResult = await resolveDestinationWithPlaces(
    interpretResult.placesQuery, userLat, userLng
  );
  
  if (!placeResult) {
    return {
      voiceResponse: `No encontré "${interpretResult.resolvedDestination}" cerca de tu ubicación. ¿Puedes ser más específico?`,
      intent: 'clarify',
      resolvedDestination: null,
      destinationCoords: null,
      route: null,
      needsClarification: true,
      clarificationQuestion: '¿Puedes darme más detalles del lugar?',
      sessionId
    };
  }
  
  // Paso 3: Calcular ruta accesible
  const routeData = await getAccessibleRoute(
    { lat: userLat, lng: userLng },
    placeResult.coords,
    userProfile,
    null // sin arrivalTime en modo voz — es para navegación inmediata
  );
  
  // Paso 4: Convertir ruta a instrucciones de voz natural
  const voiceInstructions = await routeToVoice(model, routeData.route, interpretResult.resolvedDestination);
  
  return {
    voiceResponse: voiceInstructions,
    intent: 'navigate',
    resolvedDestination: placeResult.name,
    destinationCoords: placeResult.coords,
    route: routeData.route,
    needsClarification: false,
    clarificationQuestion: null,
    sessionId
  };
}

async function interpretUserIntent(model, message, conversationHistory) {
  const historyContext = conversationHistory.length > 0
    ? `Conversación previa:\n${conversationHistory.map(h => `${h.role}: ${h.content}`).join('\n')}\n\n`
    : '';
  
  const prompt = `${GEO_INTERPRETER_PROMPT}\n\n${historyContext}Mensaje del usuario: "${message}"`;
  
  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    return JSON.parse(cleaned);
  } catch (err) {
    console.error('Error interpretando intent:', err);
    return {
      intent: 'clarify',
      clarificationQuestion: '¿Me puedes decir a dónde quieres ir?',
      confidence: 0
    };
  }
}

async function resolveDestinationWithPlaces(query, userLat, userLng) {
  const PLACES_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
  
  // Usar Places Text Search API
  const url = `https://maps.googleapis.com/maps/api/place/textsearch/json` +
    `?query=${encodeURIComponent(query)}` +
    `&location=${userLat},${userLng}` +
    `&radius=5000` +  // buscar dentro de 5km
    `&language=es` +
    `&key=${PLACES_API_KEY}`;
  
  try {
    const res = await fetch(url);
    const data = await res.json();
    
    if (data.status !== 'OK' || !data.results?.length) return null;
    
    const place = data.results[0];
    return {
      name: place.name,
      coords: {
        lat: place.geometry.location.lat,
        lng: place.geometry.location.lng
      },
      address: place.formatted_address
    };
  } catch (err) {
    console.error('Error con Places API:', err);
    return null;
  }
}

async function routeToVoice(model, routeData, destinationName) {
  const routeSummary = {
    destination: destinationName,
    distanceMeters: routeData.distanceMeters,
    durationMinutes: Math.round(routeData.durationSeconds / 60),
    accessibilityScore: routeData.accessibilityScore,
    warnings: routeData.warnings.map(w => w.message)
  };
  
  const prompt = `${ROUTE_TO_VOICE_PROMPT}\n\nDatos de la ruta:\n${JSON.stringify(routeSummary, null, 2)}`;
  
  try {
    const result = await model.generateContent(prompt);
    return result.response.text().trim();
  } catch (err) {
    // Fallback con template simple
    const mins = Math.round(routeData.durationSeconds / 60);
    const dist = routeData.distanceMeters;
    const hasWarnings = routeData.warnings.length > 0;
    
    return `Tu destino "${destinationName}" está a ${mins} minutos, a ${dist} metros de aquí.` +
      (hasWarnings ? ` Hay ${routeData.warnings.length} punto${routeData.warnings.length > 1 ? 's' : ''} con obstáculos en la ruta.` : ' La ruta no tiene obstáculos reportados.') +
      ' ¿Empezamos?';
  }
}

module.exports = { processVoiceQuery };
```

---

## Registro en index.js

```javascript
// functions/index.js (fragmento)
const { processVoiceQuery } = require('./src/voice/conversation');

exports.voiceQuery = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    
    const { message, userLat, userLng, userProfile, sessionId, conversationHistory } = req.body;
    
    if (!message || !userLat || !userLng) {
      return res.status(400).json({ error: 'message, userLat y userLng son requeridos' });
    }
    
    try {
      const result = await processVoiceQuery({
        message,
        userLat: parseFloat(userLat),
        userLng: parseFloat(userLng),
        userProfile: userProfile || 'walker',
        sessionId: sessionId || `session_${Date.now()}`,
        conversationHistory: conversationHistory || []
      });
      res.json(result);
    } catch (err) {
      console.error('Error en voice query:', err);
      res.status(500).json({ error: err.message });
    }
  });
});
```

---

## HTML de prueba — fragmento

```html
<!-- test-voice.html -->
<textarea id="mensaje" placeholder="Escribe como si hablaras: 'quiero ir al IMSS de aquí cerca'"></textarea>
<select id="perfil">
  <option value="wheelchair">Silla de ruedas</option>
  <option value="elderly">Adulto mayor</option>
  <option value="walker">Caminante</option>
</select>
<button onclick="enviarConsulta()">Enviar</button>
<div id="respuesta-voz" style="font-size: 1.2em; background: #f0f0f0; padding: 12px;"></div>

<script>
const conversationHistory = [];
const SESSION_ID = `session_${Date.now()}`;
// Coordenadas fijas para prueba: zona centro Tijuana
const USER_LAT = 32.5300;
const USER_LNG = -117.0350;

async function enviarConsulta() {
  const message = document.getElementById('mensaje').value;
  const userProfile = document.getElementById('perfil').value;
  
  const res = await fetch('https://us-central1-vialibretj.cloudfunctions.net/voiceQuery', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message,
      userLat: USER_LAT,
      userLng: USER_LNG,
      userProfile,
      sessionId: SESSION_ID,
      conversationHistory
    })
  });
  
  const data = await res.json();
  
  // Mostrar respuesta de voz
  document.getElementById('respuesta-voz').textContent = data.voiceResponse;
  
  // Usar Web Speech API para sintetizar la voz (opcional para pruebas)
  const utterance = new SpeechSynthesisUtterance(data.voiceResponse);
  utterance.lang = 'es-MX';
  speechSynthesis.speak(utterance);
  
  // Agregar al historial de conversación
  conversationHistory.push(
    { role: 'user', content: message },
    { role: 'assistant', content: data.voiceResponse }
  );
  
  // Si hay ruta, dibujarla en el mapa
  if (data.route?.encodedPolyline) {
    dibujarRuta(data.route.encodedPolyline);
  }
}
</script>
```

---

## Casos de prueba para el HTML

| Input | Comportamiento esperado |
|-------|------------------------|
| "quiero ir al IMSS de aquí cerca" | Resuelve a IMSS más cercano, devuelve ruta |
| "la farmacia" | Clarificación: "¿cuál farmacia?" |
| "necesito ir al hospital" | Resuelve a Hospital General Tijuana |
| "ir a la Coahuila" | Resuelve a Av. Coahuila Tijuana |
| "el SAT" | Resuelve a SAT Tijuana |
| "texto sin sentido xyz123" | Clarificación: "¿A dónde quieres ir?" |

## Notas de implementación

- **Historial de conversación**: mantener el `conversationHistory` en el cliente entre llamadas al endpoint. Permite que Gemini entienda contexto previo (ej. si el usuario dice "ahí" después de haber mencionado el IMSS).
- **Web Speech API**: el HTML de prueba puede usar `SpeechSynthesisUtterance` para TTS nativo del navegador. En Flutter, usar `flutter_tts`.
- **Places API vs. hardcoded**: para el hackathon, tener un mapa hardcoded de los lugares más comunes de Tijuana (IMSS, Hospital General, SAT) como fallback si Places API falla.
- **Confianza baja**: si Gemini devuelve `confidence < 0.5`, siempre ir a `clarify` aunque tenga un `placesQuery`.
- **Plan B táctil**: en el HTML de prueba, el input de texto simula la voz. En Flutter, `speech_to_text` captura la voz real, pero siempre tener un botón de texto como respaldo.
