import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:camino_front/core/config/supabase_config.dart';
import 'package:camino_front/shared/services/permission_service.dart';
import 'package:camino_front/core/services/location_service.dart';
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
  GoogleMapController? _mapController;
  LatLng? _userPosition;

  // Marcador azul de posición del usuario (usado en web; Android usa myLocationEnabled).
  Set<Marker> _userMarker = {};
  BitmapDescriptor? _blueDotDescriptor;

  // Places Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isFetchingSuggestions = false;

  static const _fallbackPosition = CameraPosition(
    target: LatLng(32.5149, -117.0382),
    zoom: 15.5,
  );

  @override
  void initState() {
    super.initState();
    _initBlueDot();
    _requestPermissions();
    _searchController.addListener(_onSearchChanged);
  }

  /// Dibuja el marcador azul de ubicación usando canvas —
  /// círculo exterior semitransparente (halo de precisión) +
  /// borde blanco + punto azul central, idéntico al de Google Maps.
  Future<void> _initBlueDot() async {
    const double size = 56;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Halo de precisión (azul semi-transparente)
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()
        ..color = const Color(0x334285F4)
        ..style = PaintingStyle.fill,
    );

    // Borde blanco
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Punto azul central
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      11,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final descriptor = BitmapDescriptor.fromBytes(
      byteData.buffer.asUint8List(),
      size: const Size(size, size),
    );

    if (mounted) setState(() => _blueDotDescriptor = descriptor);
  }

  /// Llama a Places Autocomplete con debounce de 400ms.
  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query);
    });
  }

  /// Consulta Google Places Autocomplete API.
  Future<void> _fetchSuggestions(String query) async {
    if (_isFetchingSuggestions) return;
    setState(() => _isFetchingSuggestions = true);

    try {
      final userLat = _userPosition?.latitude ?? 32.5149;
      final userLng = _userPosition?.longitude ?? -117.0382;

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': SupabaseConfig.googleMapsApiKey,
          'components': 'country:mx',
          'language': 'es',
          'location': '$userLat,$userLng',
          'radius': '50000',
        },
      );

      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        setState(() {
          _suggestions = predictions
              .cast<Map<String, dynamic>>()
              .map((p) => {
                    'place_id': p['place_id'] as String,
                    'description': p['description'] as String,
                    'main_text':
                        (p['structured_formatting']?['main_text'] as String?) ??
                            (p['description'] as String),
                    'secondary_text': (p['structured_formatting']
                            ?['secondary_text'] as String?) ??
                        '',
                  })
              .toList();
        });
      }
    } catch (_) {
      // Silencioso — la búsqueda es best-effort.
    } finally {
      if (mounted) setState(() => _isFetchingSuggestions = false);
    }
  }

  /// Obtiene las coordenadas de un place_id y navega a RouteDetailsScreen.
  Future<void> _selectPlace(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'] as String;
    final description = suggestion['description'] as String;

    // Limpiar sugerencias y actualizar el campo de texto.
    setState(() {
      _suggestions = [];
      _searchController.text = suggestion['main_text'] as String;
    });
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );

    // Obtener coordenadas del lugar seleccionado.
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry',
          'key': SupabaseConfig.googleMapsApiKey,
        },
      );

      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final location = data['result']?['geometry']?['location'];
        if (location != null) {
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final placeLatLng = LatLng(lat, lng);

          // Mover cámara al lugar seleccionado.
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: placeLatLng, zoom: 16),
            ),
          );
        }
      }
    } catch (_) {
      // Si falla details, igual navegamos con el nombre.
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDetailsScreen(destination: description),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // En web, LocationService usará la Geolocation API del navegador
      // (el browser mostrará su propio diálogo de permiso).
      await _moveToUserLocation();
      return;
    }
    final granted = await PermissionService.requestLocationPermission();
    if (!mounted) return;
    setState(() => _locationGranted = granted);
    if (granted) {
      _moveToUserLocation();
    } else {
      _showPermissionDialog();
    }
  }

  /// Obtiene la posición GPS real, mueve la cámara y actualiza el marcador azul.
  Future<void> _moveToUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;

    // Construir el marcador azul (centrado en la posición) para web.
    // En Android el dot nativo de myLocationEnabled ya lo cubre.
    final marker = _blueDotDescriptor != null
        ? Marker(
            markerId: const MarkerId('user_location'),
            position: position,
            icon: _blueDotDescriptor!,
            anchor: const Offset(0.5, 0.5),
            zIndex: 10,
            infoWindow: InfoWindow.noText,
            consumeTapEvents: false,
          )
        : null;

    setState(() {
      _userPosition = position;
      _locationGranted = true;
      if (marker != null) _userMarker = {marker};
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15.5),
      ),
    );
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
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _mapController?.dispose();
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
            initialCameraPosition: _fallbackPosition,
            onMapCreated: (controller) {
              _mapController = controller;
              // Cuando el mapa esté listo, si ya teníamos posición, centramos.
              if (_userPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _userPosition!, zoom: 15.5),
                  ),
                );
              }
            },
            // Android: dot nativo con halo de precisión y animación de pulso.
            // Web: marcador personalizado dibujado (_userMarker).
            myLocationEnabled: !kIsWeb && _locationGranted,
            myLocationButtonEnabled: false,
            markers: kIsWeb ? _userMarker : {},
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Floating Input Field + Autocomplete Suggestions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Barra de búsqueda ──
                  Container(
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
                        prefixIcon: _isFetchingSuggestions
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.location_on,
                                color: Color(0xFF4285F4),
                                size: 28,
                              ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Color(0xFF9AA0A6), size: 22),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _suggestions = []);
                                },
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.mic_rounded,
                                  color: Color(0xFF4285F4),
                                  size: 28,
                                ),
                                onPressed: _requestMicPermission,
                              ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  // ── Panel de sugerencias ──
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: _suggestions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final s = entry.value;
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () => _selectPlace(s),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.place_rounded,
                                          color: Color(0xFF4285F4),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s['main_text'] as String,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if ((s['secondary_text']
                                                      as String)
                                                  .isNotEmpty)
                                                Text(
                                                  s['secondary_text'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (i < _suggestions.length - 1)
                                  const Divider(
                                      height: 1,
                                      indent: 48,
                                      color: Color(0xFFF1F3F4)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // FAB — centrar en mi ubicación
          Positioned(
            bottom: 190,
            right: 20,
            child: Semantics(
              button: true,
              label: 'Centrar mapa en mi ubicación actual',
              child: GestureDetector(
                onTap: _moveToUserLocation,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
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

          // Floating Report Button
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
                    // Si hay sugerencias visibles, seleccionar la primera.
                    if (_suggestions.isNotEmpty) {
                      _selectPlace(_suggestions.first);
                      return;
                    }
                    setState(() => _suggestions = []);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RouteDetailsScreen(destination: destination),
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
