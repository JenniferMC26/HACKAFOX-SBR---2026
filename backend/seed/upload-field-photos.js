/**
 * upload-field-photos.js
 *
 * Script para subir fotos tomadas en campo y registrarlas como nodos
 * verificados (field_verified) en Firebase.
 *
 * Uso:
 *   node seed/upload-field-photos.js
 *
 * Antes de correr:
 *   1. Pon tus fotos en la carpeta seed/fotos/
 *   2. Edita el archivo seed/field-captures.json con los datos de cada foto
 *      (nodeId, lat, lng, y el nombre del archivo de foto)
 *   3. Ten listo serviceAccountKey.json en la raíz del proyecto
 *   4. Ten configurado .env con GEMINI_API_KEY
 *
 * No requiere servidor corriendo. Corre todo localmente desde la laptop.
 */

require('dotenv').config({ path: '../.env' });

const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

// ─── Inicializar Firebase Admin ───────────────────────────────────────────────
admin.initializeApp({
  credential: admin.credential.cert(require('../serviceAccountKey.json')),
  databaseURL: 'https://vialibretj-default-rtdb.firebaseio.com',
  storageBucket: 'vialibretj.appspot.com'
});

const db     = admin.database();
const bucket = admin.storage().bucket();
const genAI  = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// ─── Prompt de Gemini Vision (mismo que Puente Ciudadano) ────────────────────
const VISION_PROMPT = `
Eres un analizador experto de accesibilidad urbana para la ciudad de Tijuana, México.
Analiza la imagen e identifica barreras arquitectónicas que afecten a personas con
discapacidad motriz, usuarios de silla de ruedas, adultos mayores o personas con
andadera/muletas.

Responde ÚNICAMENTE con JSON válido, sin texto adicional:

{
  "barrierType": "<broken_ramp | missing_ramp | blocked_sidewalk | uneven_surface | no_curb_cut | construction | parked_vehicle | none>",
  "severity": <1-10, donde 10 = completamente imposible de pasar>,
  "passable": <true si una silla de ruedas puede pasar con dificultad>,
  "affectedProfiles": <array: "wheelchair" | "elderly" | "walker" | "stroller">,
  "description": "<descripción en español, máximo 80 caracteres>",
  "confidence": <0.0 a 1.0>,
  "temporaryObstacle": <true si es temporal como un coche, false si es permanente>
}
`;

// ─── Función principal ────────────────────────────────────────────────────────
async function main() {
  // Leer el archivo de capturas de campo
  const capturesPath = path.join(__dirname, 'field-captures.json');

  if (!fs.existsSync(capturesPath)) {
    console.error('❌ No encontré seed/field-captures.json');
    console.log('   Crea el archivo con el formato indicado al final de este script.');
    process.exit(1);
  }

  const captures = JSON.parse(fs.readFileSync(capturesPath, 'utf8'));

  console.log(`\n📋 ${captures.length} foto(s) a procesar\n`);
  console.log('─'.repeat(50));

  const resultados = [];

  for (let i = 0; i < captures.length; i++) {
    const capture = captures[i];
    console.log(`\n[${i + 1}/${captures.length}] ${capture.nodeId}`);

    const resultado = await procesarCaptura(capture);
    resultados.push(resultado);

    console.log('─'.repeat(50));
  }

  // Resumen final
  const exitosos  = resultados.filter(r => r.ok);
  const fallidos  = resultados.filter(r => !r.ok);

  console.log('\n✅ Proceso completado');
  console.log(`   Guardados : ${exitosos.length}`);
  console.log(`   Fallidos  : ${fallidos.length}`);

  if (fallidos.length > 0) {
    console.log('\n⚠️  Nodos que fallaron:');
    fallidos.forEach(r => console.log(`   - ${r.nodeId}: ${r.error}`));
  }

  process.exit(0);
}

// ─── Procesar una captura ─────────────────────────────────────────────────────
async function procesarCaptura(capture) {
  const { nodeId, lat, lng, photo } = capture;
  const photoPath = path.join(__dirname, 'fotos', photo);

  // Verificar que la foto existe
  if (!fs.existsSync(photoPath)) {
    console.log(`   ❌ Foto no encontrada: seed/fotos/${photo}`);
    return { ok: false, nodeId, error: `Foto no encontrada: ${photo}` };
  }

  try {
    // 1. Subir foto a Firebase Storage
    process.stdout.write('   ☁️  Subiendo foto... ');
    const destination = `field_verified/${nodeId}.jpg`;
    await bucket.upload(photoPath, { destination });
    const photoUrl = `gs://${bucket.name}/${destination}`;
    console.log('listo');

    // 2. Analizar con Gemini Vision
    process.stdout.write('   🤖 Analizando con Gemini... ');
    const analysis = await analizarFoto(photoPath);
    console.log('listo');

    // El score de accesibilidad (0-10) se deriva del severity de Gemini:
    //   score = 10 - severity
    //
    // Gemini evalúa severity así:
    //   1  → obstáculo casi imperceptible (grieta pequeña)
    //   3  → dificulta el paso pero no lo impide (pendiente alta, banqueta angosta)
    //   5  → paso con dificultad considerable (rampa dañada pero usable con ayuda)
    //   7  → prácticamente intransitable para silla de ruedas
    //   10 → completamente bloqueado (escalones sin rampa, obra total)
    const geminiScore = 10 - analysis.severity;

    // 3. Mostrar resultado para revisión del equipo
    console.log(`\n   📊 Análisis:`);
    console.log(`      Barrera    : ${analysis.barrierType}`);
    console.log(`      Severity   : ${analysis.severity}/10`);
    console.log(`      Score auto : ${geminiScore}/10  ← score = 10 - severity`);
    console.log(`      Pasable    : ${analysis.passable}`);
    console.log(`      Afecta a   : ${(analysis.affectedProfiles || []).join(', ') || 'ninguno'}`);
    console.log(`      Descripción: ${analysis.description}`);
    console.log(`      Confianza  : ${Math.round((analysis.confidence || 0) * 100)}%`);

    if ((analysis.confidence || 0) < 0.6) {
      console.log(`\n   ⚠️  Confianza baja — considera retomar la foto con mejor luz`);
    }

    // 4. Pedir confirmación o corrección manual del score
    const finalScore = await pedirScore(geminiScore);

    // 5. Guardar nodo en Firebase con source: field_verified
    await db.ref(`accessibility_layer/${nodeId}`).set({
      lat:          parseFloat(lat),
      lng:          parseFloat(lng),
      type:         inferirTipo(analysis.barrierType),
      accessible:   finalScore >= 5,
      score:        finalScore,
      source:       'field_verified',
      verifiedBy:   'team',
      verifiedAt:   new Date().toISOString(),
      photoUrl,
      geminiAnalysis: analysis,
      barrierType:  analysis.barrierType === 'none' ? null : analysis.barrierType,
      lastReported: new Date().toISOString(),
      reportCount:  0
    });

    console.log(`\n   ✅ "${nodeId}" guardado con score ${finalScore}/10`);
    return { ok: true, nodeId, score: finalScore };

  } catch (err) {
    console.log(`\n   ❌ Error: ${err.message}`);
    return { ok: false, nodeId, error: err.message };
  }
}

// ─── Llamar a Gemini Vision ───────────────────────────────────────────────────
async function analizarFoto(photoPath) {
  const model   = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
  const buffer  = fs.readFileSync(photoPath);
  const base64  = buffer.toString('base64');
  const mimeType = 'image/jpeg';

  const result  = await model.generateContent([
    VISION_PROMPT,
    { inlineData: { data: base64, mimeType } }
  ]);

  const text    = result.response.text().trim();
  const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();

  try {
    return JSON.parse(cleaned);
  } catch {
    // Si Gemini devuelve algo que no es JSON válido, usar fallback
    return {
      barrierType: 'unknown', severity: 5, passable: null,
      affectedProfiles: [], description: 'Revisión manual requerida',
      confidence: 0, temporaryObstacle: false
    };
  }
}

// ─── Pedir score al equipo en la terminal ────────────────────────────────────
function pedirScore(geminiScore) {
  return new Promise(resolve => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(`\n   ¿Score correcto? (Enter para aceptar ${geminiScore}, o escribe 1-10): `, input => {
      rl.close();
      const ingresado = input.trim();
      // Si el equipo no escribe nada → acepta el score calculado por Gemini
      // Si escribe un número → lo usa como override manual
      resolve(ingresado ? Math.min(10, Math.max(1, parseInt(ingresado))) : geminiScore);
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function inferirTipo(barrierType) {
  const map = {
    broken_ramp: 'ramp',    missing_ramp: 'ramp',
    blocked_sidewalk: 'sidewalk', uneven_surface: 'sidewalk',
    no_curb_cut: 'crossing', construction: 'obstacle',
    parked_vehicle: 'obstacle', none: 'sidewalk'
  };
  return map[barrierType] || 'sidewalk';
}

// ─── Arrancar ─────────────────────────────────────────────────────────────────
main();


/* ─────────────────────────────────────────────────────────────────────────────
   FORMATO DE seed/field-captures.json
   ─────────────────────────────────────────────────────────────────────────────
   Crea este archivo y llénalo antes de correr el script.
   Cada entrada = una foto que tomaste en campo.

   [
     {
       "nodeId": "node_imss_zonario_entrada",
       "lat": 32.5248,
       "lng": -117.0284,
       "photo": "imss_entrada.jpg"
     },
     {
       "nodeId": "node_rampa_destruida_av4",
       "lat": 32.5311,
       "lng": -117.0362,
       "photo": "rampa_av4.jpg"
     }
   ]

   - nodeId  : identificador único del nodo (usa el mismo de estimated-nodes.json si ya existe)
   - lat/lng : coordenadas GPS del punto (obtenlas manteniendo presionado en Google Maps)
   - photo   : nombre del archivo de foto dentro de seed/fotos/
   ───────────────────────────────────────────────────────────────────────────── */
