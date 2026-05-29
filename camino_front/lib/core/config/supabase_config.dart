import 'package:camino_front/core/config/secrets.dart';

/// Configuración de claves para PASO.
///
/// Las claves reales viven en secrets.dart (gitignoreado).
/// Para un nuevo entorno: copia secrets.example.dart → secrets.dart
/// y rellena los valores.
///
/// NUNCA hardcodees claves aquí ni las subas al repositorio.
class SupabaseConfig {
  SupabaseConfig._();

  static const supabaseUrl      = Secrets.supabaseUrl;
  static const supabaseAnonKey  = Secrets.supabaseAnonKey;
  static const groqApiKey       = Secrets.groqApiKey;
  static const googleMapsApiKey = Secrets.googleMapsApiKey;
  static const placesApiKey     = Secrets.placesApiKey;
}
