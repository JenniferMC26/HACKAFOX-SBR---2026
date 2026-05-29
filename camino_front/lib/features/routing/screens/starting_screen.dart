import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:camino_front/shared/services/permission_service.dart';
import 'route_details_screen.dart';
import 'package:camino_front/features/reporting/screens/report_barrier_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _locationGranted = false;

  static const _initialPosition = CameraPosition(
    target: LatLng(32.5149, -117.0382),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      setState(() => _locationGranted = true);
      return;
    }
    final granted = await PermissionService.requestLocationPermission();
    if (!mounted) return;
    setState(() => _locationGranted = granted);
    if (!granted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded,
                color: Color(0xFF4285F4), size: 24),
            SizedBox(width: 8),
            Text(
              'Ubicación necesaria',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          'PASO necesita acceso a tu ubicación para mostrarte '
          'rutas accesibles en tiempo real y reportar barreras '
          'cerca de ti.',
          style: TextStyle(
              fontSize: 15, color: Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Ahora no',
              style: TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings();
            },
            child: const Text(
              'Abrir ajustes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestMicPermission() async {
    final granted = await PermissionService.requestMicrophonePermission();
    if (!mounted) return;
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Micrófono activado',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF34A853),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Permiso de micrófono necesario',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEA4335),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Ajustes',
            textColor: Colors.white,
            onPressed: () => PermissionService.openSettings(),
          ),
        ),
      );
    }
  }

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
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
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
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.mic_rounded,
                        color: Color(0xFF4285F4),
                        size: 28,
                      ),
                      onPressed: _requestMicPermission,
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
