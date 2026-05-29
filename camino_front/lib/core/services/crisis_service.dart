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

    // Obtener perfil completo (movilidad + contactos de emergencia).
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

    // Notificar al contacto de emergencia real del perfil.
    await _notifyEmergencyContact(lat: lat, lng: lng, profile: profile);

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

  /// Enviar notificacion al contacto de emergencia real del usuario.
  ///
  /// Extrae el contacto de [profile] (campo emergency_contacts o
  /// telefono_emergencia) y actualiza alerted_contacts en la sesion.
  static Future<void> _notifyEmergencyContact({
    required double lat,
    required double lng,
    required Map<String, dynamic>? profile,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) return;

    try {
      // Construir lista de contactos alertados desde el perfil.
      final List<Map<String, dynamic>> alertedContacts = [];

      final rawContacts =
          profile?['emergency_contacts'] as List<dynamic>? ?? [];
      if (rawContacts.isNotEmpty) {
        for (final c in rawContacts) {
          final contact = Map<String, dynamic>.from(c as Map);
          alertedContacts.add({
            'nombre': contact['nombre'] ?? 'Contacto',
            'telefono': contact['telefono'] ?? '',
            'alertado_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // Fallback: telefono_emergencia simple del perfil.
        final phone = profile?['telefono_emergencia'] as String?;
        if (phone != null && phone.isNotEmpty) {
          alertedContacts.add({
            'nombre': 'Contacto de emergencia',
            'telefono': phone,
            'alertado_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Actualizar alerted_contacts en la sesion de crisis.
      if (_activeSessionId != null && alertedContacts.isNotEmpty) {
        await _client
            .from('crisis_sessions')
            .update({'alerted_contacts': alertedContacts})
            .eq('id', _activeSessionId!);
      }

      final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
      final contactInfo =
          alertedContacts.isNotEmpty ? alertedContacts.first : null;

      // Insertar notificacion con datos reales del contacto.
      await _client.from('notifications').insert({
        'recipient_id': uid,
        'type': 'crisis_alert',
        'from_user_id': uid,
        'session_id': _activeSessionId,
        'lat': lat,
        'lng': lng,
        'emergency_contact': contactInfo,
        'message': 'Usuario activó botón de pánico en PASO. '
            'Enlace de ubicación: $mapsLink',
      });
    } catch (_) {
      // No bloquear el flujo de crisis si falla la notificacion.
    }
  }
}
