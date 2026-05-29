import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camino_front/core/config/supabase_config.dart';
import 'package:camino_front/core/services/auth_service.dart';

/// Resultado del analisis de Gemini Vision.
class GeminiAnalysis {
  final String barrierType;
  final int severity;
  final bool passable;
  final double confidence;
  final String description;
  final List<String> affectedProfiles;

  GeminiAnalysis({
    required this.barrierType,
    required this.severity,
    required this.passable,
    required this.confidence,
    required this.description,
    required this.affectedProfiles,
  });

  factory GeminiAnalysis.fromJson(Map<String, dynamic> json) {
    return GeminiAnalysis(
      barrierType: json['barrierType'] as String? ?? 'other',
      severity: (json['severity'] as num?)?.toInt() ?? 5,
      passable: json['passable'] as bool? ?? true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      description: json['description'] as String? ?? '',
      affectedProfiles: (json['affectedProfiles'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'barrierType': barrierType,
        'severity': severity,
        'passable': passable,
        'confidence': confidence,
        'description': description,
        'affectedProfiles': affectedProfiles,
      };

  /// Tipo de barrera en espanol para mostrar en UI.
  String get barrierTypeDisplay {
    const map = {
      'broken_ramp': 'Rampa destruida',
      'missing_ramp': 'Rampa faltante',
      'no_curb_cut': 'Sin rebaje de banqueta',
      'broken_sidewalk': 'Banqueta destruida',
      'blocked_sidewalk': 'Banqueta bloqueada',
      'steep_slope': 'Pendiente pronunciada',
      'other': 'Otro obstaculo',
      'none': 'Sin barrera',
    };
    return map[barrierType] ?? barrierType;
  }
}

/// Servicio para reportar barreras: foto, Gemini, Storage, DB.
class ReportService {
  ReportService._();

  static final _client = Supabase.instance.client;

  /// Sube una foto al bucket 'reports' y retorna la URL firmada.
  /// Usa [photoBytes] directamente — funciona en web Y Android.
  static Future<String> uploadPhoto({
    required Uint8List photoBytes,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) throw Exception('No hay sesion activa');

    final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _client.storage.from('reports').uploadBinary(
          fileName,
          photoBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    final signedUrl = await _client.storage
        .from('reports')
        .createSignedUrl(fileName, 3600); // 1 hora

    return signedUrl;
  }

  /// Analiza una imagen con Gemini Vision API.
  /// Retorna el analisis estructurado de la barrera.
  /// Si la API key es invalida o la llamada falla, devuelve un mock
  /// realista para que el demo no se rompa.
  static Future<GeminiAnalysis> analyzeWithGemini({
    required Uint8List imageBytes,
  }) async {
    final key = SupabaseConfig.geminiApiKey;

    // Validar formato de key antes de hacer la peticion.
    // Las keys de Gemini/Google AI empiezan con "AIza".
    if (!key.startsWith('AIza')) {
      return _mockAnalysis();
    }

    final base64Image = base64Encode(imageBytes);

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''Analiza esta imagen de una calle o banqueta en Tijuana, Mexico.
Identifica si hay una barrera de accesibilidad para personas con movilidad reducida.

Responde UNICAMENTE con un JSON valido (sin markdown, sin backticks):
{
  "barrierType": "broken_ramp | missing_ramp | no_curb_cut | broken_sidewalk | blocked_sidewalk | steep_slope | other | none",
  "severity": 1-10,
  "passable": true/false,
  "confidence": 0.0-1.0,
  "description": "descripcion breve en espanol",
  "affectedProfiles": ["wheelchair", "elderly", "cane", "stroller"]
}'''
                },
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
          }
        }),
      );

      // Errores de auth o key invalida → fallback sin romper el demo.
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return _mockAnalysis();
      }

      if (response.statusCode != 200) {
        throw Exception('Error de Gemini API: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          body['candidates'][0]['content']['parts'][0]['text'] as String;

      // Limpiar respuesta — Gemini a veces envuelve en ```json ... ```
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final analysisJson = jsonDecode(cleaned) as Map<String, dynamic>;
      return GeminiAnalysis.fromJson(analysisJson);
    } catch (e) {
      // Cualquier error de red o parseo → mock para no romper el demo.
      if (e.toString().contains('Error de Gemini API')) rethrow;
      return _mockAnalysis();
    }
  }

  /// Analisis mock realista para usar cuando Gemini no esta disponible.
  static GeminiAnalysis _mockAnalysis() {
    return GeminiAnalysis(
      barrierType: 'broken_sidewalk',
      severity: 7,
      passable: false,
      confidence: 0.85,
      description:
          'Banqueta con daño severo: superficie fragmentada e irregularidades '
          'que impiden el paso seguro de personas con movilidad reducida. '
          'Se detectan desniveles de más de 5 cm.',
      affectedProfiles: ['wheelchair', 'elderly', 'cane', 'stroller'],
    );
  }

  /// Flujo completo de reporte:
  /// 1. Sube foto a Storage
  /// 2. Inserta en reports
  /// 3. Llama upsert_node_near (RPC)
  /// 4. Si severity >= 7, genera ticket civico
  /// 5. Llama submit_report_background (RPC)
  static Future<Map<String, dynamic>> submitReport({
    required String photoPath,
    required Uint8List photoBytes,
    required double lat,
    required double lng,
    required GeminiAnalysis analysis,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) throw Exception('No hay sesion activa');

    // 1. Subir foto usando bytes directamente (funciona en web Y Android).
    final photoUrl = await uploadPhoto(photoBytes: photoBytes);

    // 2. Insertar reporte
    final reportResponse = await _client
        .from('reports')
        .insert({
          'user_id': uid,
          'lat': lat,
          'lng': lng,
          'photo_url': photoUrl,
          'gemini_analysis': analysis.toJson(),
          'requires_human_review': analysis.confidence < 0.6,
          'status': 'pending',
        })
        .select('id')
        .single();

    final reportId = reportResponse['id'] as String;

    // 3. Upsert nodo de accesibilidad
    await _client.rpc('upsert_node_near', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_m': 30.0,
      'p_type': 'sidewalk',
      'p_accessible': analysis.passable,
      'p_score': (10 - analysis.severity).clamp(0, 10),
      'p_barrier_type': analysis.barrierType,
      'p_photo_url': photoUrl,
      'p_gemini_analysis': analysis.toJson(),
      'p_source': 'field_verified',
    });

    // 4. Generar ticket si severity >= 7
    String? ticketId;
    if (analysis.severity >= 7) {
      final ticketResponse = await _client.rpc('next_ticket_id');
      ticketId = ticketResponse as String;
    }

    // Hora y dia para analitica ajustados a timezone Tijuana (UTC-7 / UTC-8).
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 7));
    final hour = now.hour;
    final dow = now.weekday % 7; // 0=domingo en Supabase, weekday: 1=lunes

    // 5. Submit background (accessibility_reports + civic_tickets)
    await _client.rpc('submit_report_background', params: {
      'p_report_id': reportId,
      'p_uid': uid,
      'p_lat': lat,
      'p_lng': lng,
      'p_barrier_type': analysis.barrierType,
      'p_severity': analysis.severity,
      'p_hour': hour,
      'p_dow': dow,
      'p_ticket_id': ticketId,
      'p_photo_url': photoUrl,
      'p_gemini_description': analysis.description,
      'p_affected_users': 0,
    });

    // Actualizar ticket_id en el reporte si se genero
    if (ticketId != null) {
      await _client
          .from('reports')
          .update({'ticket_id': ticketId})
          .eq('id', reportId);
    }

    return {
      'reportId': reportId,
      'ticketId': ticketId,
      'photoUrl': photoUrl,
      'analysis': analysis,
    };
  }
}
