import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camino_front/features/auth/screens/register_screen.dart';
import 'package:camino_front/features/routing/screens/starting_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final isTestCredentials = phone == '6641234567' && password == '123456';
    if (!isTestCredentials && !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECCIÓN: Header
                    const SizedBox(height: 24),
                    Center(
                      child: Image.asset(
                        'assets/images/logo_full.png',
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // SECCIÓN: Credenciales de prueba (solo desarrollo)
                    if (kDebugMode)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF7E0),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFFFBBC04),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.bug_report_rounded,
                              color: Color(0xFFFBBC04),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modo prueba — solo desarrollo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5D4037),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Teléfono: 6641234567  ·  Contraseña: 123456',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5D4037),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SECCIÓN: Formulario
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Campo teléfono
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Número de teléfono',
                              hintText: '10 dígitos',
                              prefixIcon: const Icon(
                                Icons.phone_rounded,
                                color: Color(0xFF4285F4),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4285F4),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu número de teléfono';
                              }
                              if (v.length < 10) {
                                return 'El número debe tener 10 dígitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFF4285F4),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: const Color(0xFF9AA0A6),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4285F4),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              if (v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // SECCIÓN: Acción principal
                          Semantics(
                            button: true,
                            label: 'Iniciar sesión en PASO',
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4285F4),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SECCIÓN: Navegación a registro
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                  children: [
                                    TextSpan(text: '¿No tienes cuenta? '),
                                    TextSpan(
                                      text: 'Regístrate aquí',
                                      style: TextStyle(
                                        color: Color(0xFF4285F4),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
