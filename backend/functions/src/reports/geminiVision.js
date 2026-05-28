// Wrapper de Gemini Vision para analizar fotos de barreras de accesibilidad.
//
// Si GEMINI_API_KEY no está seteada, devuelve una respuesta MOCK determinista
// basada en el path de la foto para que el pipeline de reportes corra contra
// el emulador sin internet.

const USE_MOCK_GEMINI = !process.env.GEMINI_API_KEY;

const PROMPT = `Eres un evaluador de accesibilidad urbana. Analiza la foto y devuelve
SOLO un JSON con esta forma:
{
  "barrierType": "broken_ramp|missing_ramp|blocked_sidewalk|no_curb_cut|uneven_surface|construction|parked_vehicle|none",
  "severity": 1-10,
  "passable": true|false,
  "affectedProfiles": ["wheelchair","elderly","cane","stroller"],
  "description": "1-2 oraciones en español",
  "confidence": 0.0-1.0
}
Severity 1 = casi imperceptible. 10 = completamente bloqueado.`;

function mockAnalysis(photoUrl) {
  // Determinista a partir del path — útil para reproducir tests.
  const seed = (photoUrl || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const variants = [
    {
      barrierType: 'broken_ramp',
      severity: 7,
      passable: false,
      affectedProfiles: ['wheelchair', 'elderly'],
      description: '[MOCK] Rampa con grietas profundas que impide el paso de silla de ruedas.',
      confidence: 0.82,
    },
    {
      barrierType: 'blocked_sidewalk',
      severity: 5,
      passable: true,
      affectedProfiles: ['wheelchair', 'stroller'],
      description: '[MOCK] Banqueta parcialmente bloqueada por puestos ambulantes.',
      confidence: 0.74,
    },
    {
      barrierType: 'no_curb_cut',
      severity: 8,
      passable: false,
      affectedProfiles: ['wheelchair'],
      description: '[MOCK] Cruce sin rampa peatonal en la esquina.',
      confidence: 0.88,
    },
    {
      barrierType: 'none',
      severity: 1,
      passable: true,
      affectedProfiles: [],
      description: '[MOCK] Banqueta despejada y en buen estado.',
      confidence: 0.91,
    },
  ];
  return variants[seed % variants.length];
}

async function analyzeBarrierPhoto(photoUrl) {
  if (USE_MOCK_GEMINI) return mockAnalysis(photoUrl);

  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

  // Descargar la foto y mandarla inline como base64.
  const res = await fetch(photoUrl);
  if (!res.ok) throw new Error(`No se pudo descargar la foto (${res.status})`);
  const buf = Buffer.from(await res.arrayBuffer());
  const mimeType = res.headers.get('content-type') || 'image/jpeg';

  const result = await model.generateContent([
    PROMPT,
    { inlineData: { mimeType, data: buf.toString('base64') } },
  ]);
  const text = result.response.text();

  // Gemini a veces envuelve el JSON en ```json … ``` — limpiar.
  const cleaned = text.replace(/```json|```/g, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch (err) {
    throw new Error(`Gemini no devolvió JSON parseable: ${text.slice(0, 200)}`);
  }
}

module.exports = { analyzeBarrierPhoto };
