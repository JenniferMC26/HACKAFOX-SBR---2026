import 'package:flutter/material.dart';
import 'route_details_screen.dart';
import '../../reporting/screens/report_barrier_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Estado inicial simulado
  final bool _hasAlert = true;
  final String _destination = "IMSS Clínica 1";
  final String _mobilityMode = "Bastón";
  final String _alertMessage = "Rampa bloqueada · 80m adelante";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CAPA 1 — Fondo del mapa
          Container(
            color: const Color(0xFFF1F3F4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 80,
                    color: const Color(0xFF9AA0A6).withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ruta activa · Centro, Tijuana',
                    style: TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CAPA 2 — Banner superior flotante
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _destination,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_walk_rounded,
                            color: Color(0xFF4285F4),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "14 min · 1.1 km",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            " · $_mobilityMode",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4285F4),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CAPA 3 — Card de alerta
          if (_hasAlert)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF7E0),
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFFBBC04), width: 4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFBBC04),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Barrera detectada",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _alertMessage,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Acción de dummy para recalcular ruta
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Ver ruta alternativa",
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // CAPA 4 — FAB de ubicación
          Positioned(
            bottom: 112,
            right: 20,
            child: Semantics(
              button: true,
              label: "Centrar mapa en mi ubicación",
              child: GestureDetector(
                onTap: () {
                  // Acción de dummy para centrar ubicación
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF4285F4),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // CAPA 5 — Barra inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: "Reportar una barrera en la ruta actual",
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.report_problem_rounded),
                            label: const Text(
                              "Reportar barrera",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4285F4),
                              side: const BorderSide(
                                color: Color(0xFF4285F4),
                                width: 2, // Grosor ajustado para accesibilidad
                              ),
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ReportBarrierScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: "Terminar la navegación y volver al inicio",
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.stop_circle_rounded),
                            label: const Text(
                              "Finalizar viaje",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA4335),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            onPressed: () {
                              Navigator.popUntil(context, (r) => r.isFirst);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
