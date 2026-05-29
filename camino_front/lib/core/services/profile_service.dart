import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camino_front/core/services/auth_service.dart';

/// Servicio para gestionar perfiles de usuario en user_profiles.
class ProfileService {
  ProfileService._();

  static final _client = Supabase.instance.client;

  /// Obtiene el perfil del usuario actual.
  /// Retorna null si no existe.
  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = AuthService.uid;
    if (uid == null) return null;

    final response = await _client
        .from('user_profiles')
        .select()
        .eq('uid', uid)
        .maybeSingle();

    return response;
  }

  /// Crea o actualiza el perfil del usuario.
  ///
  /// Campos del frontend:
  /// - nombre: nombre completo
  /// - telefono: numero de telefono (10 digitos)
  /// - mobility: tipo de movilidad (se mapea a mobility_type y tipo_discapacidad)
  /// - emergencyContactName: nombre del contacto de emergencia
  /// - emergencyContactPhone: telefono del contacto de emergencia
  static Future<void> upsertProfile({
    String? nombre,
    String? telefono,
    String? mobility,
    List<String>? additionalOptions,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final uid = AuthService.uid;
    if (uid == null) throw Exception('No hay sesion activa');

    final data = <String, dynamic>{
      'uid': uid,
    };

    if (nombre != null) data['nombre'] = nombre;
    if (telefono != null) data['telefono'] = telefono;

    // Mapear opciones de movilidad del frontend a campos de DB
    if (mobility != null) {
      final mapping = _mapMobility(mobility, additionalOptions ?? []);
      data.addAll(mapping);
    }

    // Contacto de emergencia
    if (emergencyContactName != null || emergencyContactPhone != null) {
      data['telefono_emergencia'] = emergencyContactPhone;
      // Guardar contacto completo en emergency_contacts JSONB
      if (emergencyContactName != null && emergencyContactPhone != null) {
        data['emergency_contacts'] = [
          {
            'nombre': emergencyContactName,
            'telefono': emergencyContactPhone,
          }
        ];
      }
    }

    await _client.from('user_profiles').upsert(data);
  }

  /// Mapea la seleccion de movilidad del frontend a campos de la DB.
  static Map<String, dynamic> _mapMobility(
    String mobility,
    List<String> additionalOptions,
  ) {
    final result = <String, dynamic>{};

    switch (mobility) {
      case 'Estandar':
      case 'Estándar':
        result['mobility_type'] = 'none';
        result['tipo_discapacidad'] = 'ninguna';
        result['avoid_steps'] = false;
        result['avoid_slopes'] = false;
        break;
      case 'Silla de ruedas':
        result['mobility_type'] = 'wheelchair';
        result['tipo_discapacidad'] = 'motriz_silla';
        result['avoid_steps'] = true;
        result['avoid_slopes'] = true;
        result['slope_max_percent'] = 6.0;
        break;
      case 'Baston':
      case 'Bastón':
        result['mobility_type'] = 'cane';
        result['tipo_discapacidad'] = 'motriz_baston';
        result['avoid_steps'] = false;
        result['avoid_slopes'] = true;
        result['slope_max_percent'] = 10.0;
        break;
      case 'Andadera':
        result['mobility_type'] = 'elderly';
        result['tipo_discapacidad'] = 'motriz_baston';
        result['avoid_steps'] = true;
        result['avoid_slopes'] = true;
        result['slope_max_percent'] = 8.0;
        break;
      case 'Adulto mayor':
        result['mobility_type'] = 'elderly';
        result['tipo_discapacidad'] = 'adulto_mayor';
        result['avoid_steps'] = additionalOptions.contains('Silla de ruedas');
        result['avoid_slopes'] = true;
        result['slope_max_percent'] = 8.0;
        break;
    }

    return result;
  }
}
