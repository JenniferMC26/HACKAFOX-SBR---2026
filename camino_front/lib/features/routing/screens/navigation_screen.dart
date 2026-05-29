import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:camino_front/features/reporting/screens/report_barrier_screen.dart';
import 'package:camino_front/features/emergency/screens/panic_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    this.destination = 'IMSS Clínica 1 — Tijuana',
  });

  final String destination;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final bool _hasAlert = true;
  late final String _destination;
  GoogleMapController? _mapController;

  static const _initialPosition = CameraPosition(
    target: LatLng(32.5149, -117.0382),
    zoom: 15.5,
  );

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('destination'),
      position: LatLng(32.5169, -117.0352),
      infoWindow: InfoWindow(title: 'IMSS Clínica 1'),
    ),
  };

  final Set<Polyline> _polylines = {
    const Polyline(
      polylineId: PolylineId('route'),
      points: [
        LatLng(32.5149, -117.0382),
        LatLng(32.5155, -117.0370),
        LatLng(32.5162, -117.0358),
        LatLng(32.5169, -117.0352),
      ],
      color: Color(0xFF4285F4),
      width: 5,
    ),
  };

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
  }

  final String _mobilityMode = "Silla de ruedas";
  final String _alertMessage = "Banqueta bloqueada · Calle 2da y Constitución";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CAPA 1 — Fondo del mapa
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // CAPA 2 — Banner superior flotante
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
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
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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

          // CAPA 3 — Card de alerta (solo si _hasAlert == true)
          if (_hasAlert)
            Positioned(
              top: 130,
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
                                  color: Colors.black,
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
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4285F4),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text("Ver ruta alternativa"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // CAPA 4 — FAB de ubicación
          Positioned(
            bottom: 108,
            right: 20,
            child: Semantics(
              button: true,
              label: "Centrar mapa en mi ubicación",
              child: GestureDetector(
                onTap: () => _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(_initialPosition),
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
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
            child: SafeArea(
              bottom: true,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: "Reportar una barrera en la ruta actual",
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.report_problem_rounded),
                              label: const Text("Reportar barrera"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4285F4),
                                side: const BorderSide(color: Color(0xFF4285F4)),
                                minimumSize: const Size(double.infinity, 56),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportBarrierScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: "Terminar navegación y volver al inicio",
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.stop_circle_rounded),
                              label: const Text("Finalizar viaje"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA4335),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                              onPressed: () => Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'Activar botón de pánico de emergencia',
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.warning_rounded),
                          label: const Text(
                            'Botón de pánico',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDECEA),
                            foregroundColor: const Color(0xFFEA4335),
                            elevation: 0,
                            side: const BorderSide(
                              color: Color(0xFFEA4335),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PanicScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
