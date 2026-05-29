import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camino_front/core/services/auth_service.dart';
import 'package:camino_front/core/services/profile_service.dart';

/// Servicio para el Modo Crisis (boton de panico).
///
/// Flujo:
/// 1. Crear crisis_session con ubicacion actual
/// 2. Suscribirse a Realtime para recibir nearest_safe_point
/// 3. Actualizar ubicacion periodicamente
/// 4. Resolver la sesion al terminar
class CrisisService {
  CrisisService._();

  static final _client = Supabase.instance.client;
  static RealtimeChannel? _channel;
  static String? _activeSessionId;

  /// ID de la sesion activa (null si no hay crisis).
  static String? get activeSessionId => _activeSessionId;

  /// Inicia una sesion de crisis.
  /// Retorna el ID de la sesion creada.
  static Future<String> startCrisis({
    required double lat,
    required double lng,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) throw Exception('No hay sesion activa');

    // Obtener perfil para snapshot
    final profile = await ProfileService.getProfile();

    final response = await _client
        .from('crisis_sessions')
        .insert({
          'user_id': uid,
          'current_lat': lat,
          'current_lng': lng,
          'user_profile': {
            'mobility_type': profile?['mobility_type'] ?? 'none',
          },
          'status': 'active',
          'last_update': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    _activeSessionId = response['id'] as String;

    // Notificar contacto de emergencia
    await _notifyEmergencyContact(lat: lat, lng: lng);

    return _activeSessionId!;
  }

  /// Suscribirse a cambios en la sesion de crisis (nearest_safe_point).
  static Stream<Map<String, dynamic>> subscribeToCrisis(String sessionId) {
    final controller = StreamController<Map<String, dynamic>>();

    _channel = _client
        .channel('crisis-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'crisis_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            controller.add(payload.newRecord);
          },
        )
        .subscribe();

    controller.onCancel = () {
      _channel?.unsubscribe();
      _channel = null;
    };

    return controller.stream;
  }

  /// Actualiza la ubicacion en la sesion de crisis activa.
  static Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    if (_activeSessionId == null) return;

    await _client
        .from('crisis_sessions')
        .update({
          'current_lat': lat,
          'current_lng': lng,
          'last_update': DateTime.now().toIso8601String(),
        })
        .eq('id', _activeSessionId!);
  }

  /// Resuelve la sesion de crisis.
  static Future<void> resolveCrisis() async {
    if (_activeSessionId == null) return;

    await _client
        .from('crisis_sessions')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', _activeSessionId!);

    _channel?.unsubscribe();
    _channel = null;
    _activeSessionId = null;
  }

  /// Enviar notificacion al contacto de emergencia.
  static Future<void> _notifyEmergencyContact({
    required double lat,
    required double lng,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) return;

    try {
      await _client.from('notifications').insert({
        'recipient_id': uid, // Auto-notificacion; en produccion seria el contacto
        'type': 'crisis_alert',
        'from_user_id': uid,
        'session_id': _activeSessionId,
        'lat': lat,
        'lng': lng,
      });
    } catch (_) {
      // No bloquear el flujo de crisis si falla la notificacion
    }
  }
}
