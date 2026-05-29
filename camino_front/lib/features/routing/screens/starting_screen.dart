import 'package:flutter/material.dart';
import 'route_details_screen.dart';
import 'package:camino_front/features/reporting/screens/report_barrier_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          // MODIFICACIÓN: Se cambió el ícono a Icons.map_rounded y el texto a "Cargando mapa de Tijuana...".
          // Se ajustó el color a #9AA0A6 para cumplir con las directrices visuales.
          Container(
            color: const Color(0xFFF1F3F4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 80,
                    color: const Color(0xFF9AA0A6).withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cargando mapa de Tijuana...',
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

          // Floating Input Field
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ingrese su destino...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: Color(0xFF4285F4),
                      size: 28,
                    ),
                    suffixIcon: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFF4285F4),
                      size: 28,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),

          // Floating Report Button
          // MODIFICACIÓN: Se agregó un FAB secundario para reportar barreras usando el color
          // amarillo Google (#FBBC04). Se envolvió en Semantics para lectores de pantalla.
          Positioned(
            bottom: 120,
            right: 20,
            child: Semantics(
              button: true,
              label: 'Reportar barrera arquitectónica en la calle',
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportBarrierScreen()));
                },
                backgroundColor: const Color(0xFFFBBC04),
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.black,
                ),
                label: const Text(
                  'Reportar barrera',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Semantics(
              button: true,
              label: 'Confirmar destino para calcular ruta accesible',
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: () {
                    final destination = _searchController.text.trim();
                    if (destination.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa un destino para continuar'),
                          backgroundColor: Color(0xFF4285F4),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteDetailsScreen(destination: destination),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, color: Colors.white, size: 26),
                      SizedBox(width: 12),
                      Text(
                        'Confirmar destino',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Colors.white,
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
