import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticacion con Supabase Phone Auth.
///
/// Usa telefono + password como metodo de autenticacion.
/// El UID de Supabase Auth se usa como PK en user_profiles.
class AuthService {
  AuthService._();

  static final _client = Supabase.instance.client;

  /// Usuario actual (null si no hay sesion).
  static User? get currentUser => _client.auth.currentUser;

  /// UID del usuario actual.
  static String? get uid => currentUser?.id;

  /// Telefono del usuario actual.
  static String? get phone => currentUser?.phone;

  /// Hay sesion activa?
  static bool get isLoggedIn => currentUser != null;

  /// Stream de cambios de autenticacion.
  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Registrar nuevo usuario con telefono y password.
  ///
  /// El telefono debe incluir codigo de pais, ej: +526641234567
  /// Supabase Phone Auth requiere formato E.164.
  static Future<AuthResponse> signUp({
    required String phone,
    required String password,
  }) async {
    final formattedPhone = _formatPhone(phone);
    return await _client.auth.signUp(
      phone: formattedPhone,
      password: password,
    );
  }

  /// Iniciar sesion con telefono y password.
  static Future<AuthResponse> signIn({
    required String phone,
    required String password,
  }) async {
    final formattedPhone = _formatPhone(phone);
    return await _client.auth.signInWithPassword(
      phone: formattedPhone,
      password: password,
    );
  }

  /// Cerrar sesion.
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Formatea un telefono mexicano de 10 digitos a formato E.164.
  /// Si ya tiene +52, lo deja como esta.
  /// Si tiene 10 digitos, le agrega +52 (Mexico).
  static String _formatPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.length == 10) return '+52$cleaned';
    if (cleaned.length == 12 && cleaned.startsWith('52')) return '+$cleaned';
    return '+52$cleaned';
  }
}
