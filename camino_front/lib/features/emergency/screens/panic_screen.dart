import 'package:flutter/material.dart';
import 'package:camino_front/features/routing/screens/starting_screen.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  bool _isActivated = false;
  bool _isCounting = false;
  int _countdown = 3;

  void _startCountdown() {
    if (_isCounting) return;
    setState(() {
      _isCounting = true;
      _countdown = 3;
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (int i = 3; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isCounting) return;
      setState(() => _countdown = i - 1);
    }
    if (!mounted || !_isCounting) return;
    setState(() {
      _isActivated = true;
      _isCounting = false;
    });
  }

  void _cancelCountdown() {
    if (_isCounting) {
      setState(() {
        _isCounting = false;
        _countdown = 3;
      });
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF34A853), size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Botón de pánico',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // SECCIÓN: Estado normal
                      if (!_isActivated) ...[
                        const Icon(
                          Icons.shield_rounded,
                          size: 72,
                          color: Color(0xFF4285F4),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '¿Necesitas ayuda?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Presiona el botón si no puedes continuar tu ruta. Notificaremos a tu contacto de emergencia y registraremos tu ubicación.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Botón SOS principal
                        Semantics(
                          button: true,
                          label: 'Activar botón de pánico y alertar contacto de emergencia',
                          child: GestureDetector(
                            onTap: _startCountdown,
                            onTapCancel: _cancelCountdown,
                            onTapUp: (_) {
                              if (!_isActivated) _cancelCountdown();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: _isCounting
                                    ? const Color(0xFFEA4335)
                                    : const Color(0xFFFDECEA),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFEA4335),
                                  width: _isCounting ? 4 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA4335)
                                        .withValues(alpha: 0.3),
                                    blurRadius: _isCounting ? 40 : 20,
                                    spreadRadius: _isCounting ? 8 : 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    size: 64,
                                    color: _isCounting
                                        ? Colors.white
                                        : const Color(0xFFEA4335),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isCounting
                                        ? '$_countdown'
                                        : 'SOS',
                                    style: TextStyle(
                                      fontSize: _isCounting ? 40 : 28,
                                      fontWeight: FontWeight.w900,
                                      color: _isCounting
                                          ? Colors.white
                                          : const Color(0xFFEA4335),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_isCounting)
                          Text(
                            'Suelta para cancelar — activando en $_countdown...',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFFEA4335),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          )
                        else
                          const Text(
                            'Mantén presionado 3 segundos para activar',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 32),

                        // SECCIÓN: Card informativa
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '¿Qué pasa al activarlo?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.location_on_rounded,
                                'Se registra tu ubicación exacta',
                                const Color(0xFF4285F4),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.notifications_rounded,
                                'Se notifica a tu contacto de emergencia',
                                const Color(0xFFEA4335),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.map_rounded,
                                'Se marca el punto en el mapa de la comunidad',
                                const Color(0xFF34A853),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // SECCIÓN: Estado activado
                      if (_isActivated) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F4EA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 64,
                            color: Color(0xFF34A853),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Alerta enviada',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu contacto de emergencia fue notificado y tu ubicación fue registrada. El equipo de PASO está al tanto.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // SECCIÓN: Card de confirmación
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildConfirmRow(
                                Icons.access_time_rounded,
                                'Hora de alerta',
                                _getCurrentTime(),
                              ),
                              const Divider(
                                color: Color(0xFFC8E6C9),
                                height: 24,
                              ),
                              _buildConfirmRow(
                                Icons.location_on_rounded,
                                'Ubicación',
                                'Centro, Tijuana',
                              ),
                              const Divider(
                                color: Color(0xFFC8E6C9),
                                height: 24,
                              ),
                              _buildConfirmRow(
                                Icons.person_rounded,
                                'Contacto notificado',
                                'Contacto de emergencia',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // SECCIÓN: Botones post-activación
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.home_rounded),
                            label: const Text(
                              'Volver al inicio',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MapScreen(),
                              ),
                              (route) => false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text(
                              'Seguir en mi ruta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4285F4),
                              side: const BorderSide(
                                color: Color(0xFF4285F4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
