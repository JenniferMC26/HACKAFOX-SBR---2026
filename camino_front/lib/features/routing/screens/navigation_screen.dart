import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:camino_front/features/reporting/screens/report_barrier_screen.dart';
import 'package:camino_front/features/emergency/screens/panic_screen.dart';
import 'package:camino_front/features/routing/services/routing_service.dart';
import 'package:camino_front/features/routing/services/route_graph.dart';

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
  bool _hasAlert = true;
  bool _isAlternativeRoute = false;
  late final String _destination;
  GoogleMapController? _mapController;

  // Ruteo real
  double _minScoreThreshold = 2.0;
  LatLng? _tappedDestination;
  RouteResult? _currentRoute;
  bool _isCalculatingRoute = false;
  final bool _showIntersections = false;

  static const _initialPosition = CameraPosition(
    target: LatLng(32.5149, -117.0382),
    zoom: 15.5,
  );

  final Set<Marker> _barrierMarkers = {
    Marker(
      markerId: const MarkerId('barrier_1'),
      position: const LatLng(32.5158, -117.0371),
      infoWindow: const InfoWindow(
        title: '⚠️ Barrera alta',
        snippet: 'Banqueta destruida · Reportado hace 10 min',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ),
    Marker(
      markerId: const MarkerId('barrier_2'),
      position: const LatLng(32.5163, -117.0365),
      infoWindow: const InfoWindow(
        title: '⚠️ Barrera media',
        snippet: 'Auto bloqueando rampa · Reportado hace 25 min',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    ),
    Marker(
      markerId: const MarkerId('barrier_3'),
      position: const LatLng(32.5155, -117.0378),
      infoWindow: const InfoWindow(
        title: '✅ Barrera leve',
        snippet: 'Bache pequeño · Reportado hace 1 hora',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
    Marker(
      markerId: const MarkerId('destination'),
      position: const LatLng(32.5169, -117.0352),
      infoWindow: const InfoWindow(
        title: '🏥 IMSS Clínica 1',
        snippet: 'Tu destino',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ),
    Marker(
      markerId: const MarkerId('current_location'),
      position: const LatLng(32.5149, -117.0382),
      infoWindow: const InfoWindow(
        title: '📍 Tu ubicación actual',
        snippet: 'Estás aquí',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ),
  };

  final String _mobilityMode = "Silla de ruedas";
  final String _alertMessage = "Banqueta bloqueada · Calle 2da y Constitución";

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    _initRouting();
  }

  Future<void> _initRouting() async {
    await RoutingService.instance.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _calculateRoute(LatLng destination) async {
    setState(() {
      _isCalculatingRoute = true;
      _tappedDestination = destination;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    const origin = LatLng(32.5149, -117.0382);
    final result = RoutingService.instance.findRoute(
      origin: origin,
      destination: destination,
      minScore: _minScoreThreshold,
    );

    if (!mounted) return;
    setState(() {
      _currentRoute = result;
      _isCalculatingRoute = false;
    });

    if (result.found) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ruta encontrada · ${result.segmentsCount} tramos · '
            'Accesibilidad: ${result.avgAccessibility.toStringAsFixed(1)}/4.0',
          ),
          backgroundColor: const Color(0xFF34A853),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay ruta con ese nivel mínimo de accesibilidad. '
            'Intenta bajar el filtro.',
          ),
          backgroundColor: const Color(0xFFEA4335),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _switchToAlternativeRoute() {
    setState(() {
      _hasAlert = false;
      _isAlternativeRoute = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Ruta alternativa calculada',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF34A853),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 3.5) return const Color(0xFF34A853);
    if (score >= 2.5) return const Color(0xFF4285F4);
    if (score >= 1.5) return const Color(0xFFFBBC04);
    return const Color(0xFFEA4335);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // CAPA 1 — Fondo del mapa
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              ..._barrierMarkers,
              if (_tappedDestination != null)
                Marker(
                  markerId: const MarkerId('tapped_dest'),
                  position: _tappedDestination!,
                  infoWindow: const InfoWindow(
                    title: '🎯 Destino seleccionado',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet,
                  ),
                ),
              if (_showIntersections)
                ...RoutingService.instance.intersectionMarkers,
            },
            polylines: {
              if (_currentRoute == null)
                const Polyline(
                  polylineId: PolylineId('route_default'),
                  points: [
                    LatLng(32.5149, -117.0382),
                    LatLng(32.5155, -117.0370),
                    LatLng(32.5162, -117.0358),
                    LatLng(32.5169, -117.0352),
                  ],
                  color: Color(0xFF4285F4),
                  width: 5,
                ),
              if (_currentRoute != null && _currentRoute!.found)
                Polyline(
                  polylineId: const PolylineId('route_calculated'),
                  points: _currentRoute!.polylinePoints,
                  color: const Color(0xFF34A853),
                  width: 6,
                  patterns: [
                    PatternItem.dash(20),
                    PatternItem.gap(10),
                  ],
                ),
            },
            onTap: _calculateRoute,
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
                          Text(
                            _isAlternativeRoute
                                ? "19 min · 1.6 km — ruta alternativa"
                                : "14 min · 1.1 km",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
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
                      if (_isAlternativeRoute)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                size: 12,
                                color: Color(0xFF34A853),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Evita 1 barrera',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF34A853),
                                  fontWeight: FontWeight.w700,
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
                        onPressed: _switchToAlternativeRoute,
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
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(
                      target: LatLng(32.5149, -117.0382),
                      zoom: 16.0,
                    ),
                  ),
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

          // CAPA 5 — Panel de filtro de accesibilidad
          Positioned(
            bottom: 180,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF4285F4),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Filtro de accesibilidad mínima",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _scoreColor(_minScoreThreshold),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_minScoreThreshold.toStringAsFixed(1)} / 4.0',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Más rutas',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF4285F4),
                            thumbColor: const Color(0xFF4285F4),
                            inactiveTrackColor: const Color(0xFFE0E0E0),
                            overlayColor: const Color(0xFF4285F4)
                                .withValues(alpha: 0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _minScoreThreshold,
                            min: 1.0,
                            max: 4.0,
                            divisions: 6,
                            onChanged: (value) {
                              setState(() => _minScoreThreshold = value);
                              if (_tappedDestination != null) {
                                _calculateRoute(_tappedDestination!);
                              }
                            },
                          ),
                        ),
                      ),
                      const Text(
                        'Solo óptimas',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (_tappedDestination == null)
                    const Center(
                      child: Text(
                        '👆 Toca cualquier punto del mapa para calcular la ruta',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (_isCalculatingRoute)
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculando ruta accesible...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_currentRoute != null && _currentRoute!.found)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF34A853),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(_currentRoute!.totalDistance / 1000).toStringAsFixed(2)} km · '
                          '${_currentRoute!.segmentsCount} tramos · '
                          'Score: ${_currentRoute!.avgAccessibility.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF34A853),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // CAPA 6 — Barra inferior
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
                                side: const BorderSide(
                                  color: Color(0xFF4285F4),
                                ),
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
