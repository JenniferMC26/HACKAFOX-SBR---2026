import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:camino_front/core/config/supabase_config.dart';
import 'package:camino_front/core/services/location_service.dart';
import 'package:camino_front/core/services/places_js_service.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  bool _locationGranted = false;
  LatLng? _currentPosition;
  bool _locationLoading = true;

  // Mapa
  GoogleMapController? _mapController;

  // Blue dot
  Set<Marker> _userMarker = {};
  BitmapDescriptor? _blueDotDescriptor;
  StreamSubscription<LatLng>? _positionSub;

  // Places Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isFetchingSuggestions = false;

  // Fix: flag para ignorar el cambio de texto que dispara _selectPlace
  bool _ignoreNextChange = false;
  // Fix: contador de secuencia para descartar respuestas obsoletas
  int _requestSeq = 0;

  // Destinos frecuentes de Tijuana — fallback cuando Places API no responde.
  static const _fallbackPlaces = [
    {'place_id': 'fb_imss1', 'description': 'IMSS Clínica 1 Tijuana, Zona Río', 'main_text': 'IMSS Clínica 1 Tijuana', 'secondary_text': 'Blvd. Rodolfo Sánchez Taboada, Zona Río', 'lat': 32.5209, 'lng': -117.0261},
    {'place_id': 'fb_hg', 'description': 'Hospital General de Tijuana', 'main_text': 'Hospital General de Tijuana', 'secondary_text': 'Av. Centenario 10851, La Mesa', 'lat': 32.5268, 'lng': -117.0189},
    {'place_id': 'fb_ccultural', 'description': 'Centro Cultural Tijuana (CECUT)', 'main_text': 'Centro Cultural Tijuana (CECUT)', 'secondary_text': 'Paseo de los Héroes 9350, Zona Río', 'lat': 32.5259, 'lng': -117.0244},
    {'place_id': 'fb_plaza_rio', 'description': 'Plaza Río Tijuana, Zona Río', 'main_text': 'Plaza Río Tijuana', 'secondary_text': 'Paseo de los Héroes 96, Zona Río', 'lat': 32.5262, 'lng': -117.0237},
    {'place_id': 'fb_garita', 'description': 'Garita El Chaparral, Centro Tijuana', 'main_text': 'Garita El Chaparral', 'secondary_text': 'Frontera México–EE.UU., Centro', 'lat': 32.5332, 'lng': -117.0388},
    {'place_id': 'fb_uabc', 'description': 'UABC Tijuana, Mesa de Otay', 'main_text': 'UABC Tijuana', 'secondary_text': 'Calzada Tecnológico 14418, Mesa de Otay', 'lat': 32.5411, 'lng': -116.9700},
    {'place_id': 'fb_aero', 'description': 'Aeropuerto Internacional de Tijuana', 'main_text': 'Aeropuerto Internacional de Tijuana', 'secondary_text': 'Mesa de Otay', 'lat': 32.5411, 'lng': -116.9703},
    {'place_id': 'fb_imss2', 'description': 'IMSS UMF 27 Tijuana, La Mesa', 'main_text': 'IMSS UMF 27 Tijuana', 'secondary_text': 'Av. La Mesa, La Mesa', 'lat': 32.5215, 'lng': -117.0021},
    {'place_id': 'fb_parque', 'description': 'Parque Teniente Guerrero, Centro Tijuana', 'main_text': 'Parque Teniente Guerrero', 'secondary_text': 'Av. Primera, Centro', 'lat': 32.5283, 'lng': -117.0365},
    {'place_id': 'fb_dif', 'description': 'DIF Municipal Tijuana, Zona Centro', 'main_text': 'DIF Municipal Tijuana', 'secondary_text': 'Av. Ocampo, Zona Centro', 'lat': 32.5271, 'lng': -117.0350},
  ];

  @override
  void initState() {
    super.initState();
    _initBlueDot();
    _requestPermissions();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  // ── Blue dot ────────────────────────────────────────────────────────────

  Future<void> _initBlueDot() async {
    const double size = 56;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
        Paint()..color = const Color(0x334285F4));
    canvas.drawCircle(const Offset(size / 2, size / 2), 15,
        Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(size / 2, size / 2), 11,
        Paint()..color = const Color(0xFF4285F4));

    final img = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;

    setState(() => _blueDotDescriptor = BitmapDescriptor.fromBytes(
          bytes.buffer.asUint8List(),
          size: const Size(size, size),
        ));

    if (_currentPosition != null) _updateUserMarker(_currentPosition!);
  }

  void _updateUserMarker(LatLng position) {
    if (_blueDotDescriptor == null || !mounted) return;
    setState(() {
      _userMarker = {
        Marker(
          markerId: const MarkerId('user_location'),
          position: position,
          icon: _blueDotDescriptor!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 10,
          infoWindow: InfoWindow.noText,
          consumeTapEvents: false,
        ),
      };
    });
  }

  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 16),
        ),
      );
    } else {
      _moveToUserLocation();
    }
  }

  // ── Localización ────────────────────────────────────────────────────────

  Future<void> _moveToUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _locationGranted = true;
      _locationLoading = false;
    });
    _updateUserMarker(position);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
    _startPositionTracking();
  }

  void _startPositionTracking() {
    _positionSub?.cancel();
    _positionSub = LocationService.positionStream().listen(
      (position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _updateUserMarker(position);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  // ── Places Autocomplete ─────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterFallback(String query) {
    final q = query.toLowerCase();
    return _fallbackPlaces
        .where((p) =>
            (p['main_text'] as String).toLowerCase().contains(q) ||
            (p['secondary_text'] as String).toLowerCase().contains(q))
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  /// Obtiene lugares cercanos al usuario.
  /// Web → Places JS API (sin CORS).
  /// Android/iOS → Places REST API directa.
  Future<void> _fetchNearbyPlaces() async {
    final lat = _currentPosition?.latitude ?? 32.5149;
    final lng = _currentPosition?.longitude ?? -117.0382;

    final mySeq = ++_requestSeq;
    if (mounted) setState(() => _isFetchingSuggestions = true);

    try {
      List<Map<String, dynamic>> places;

      if (kIsWeb) {
        // En web la REST API es bloqueada por CORS — usamos Places JS API.
        places = await fetchNearbyPlacesJS(lat, lng);
      } else {
        // Android/iOS → llamada REST directa, sin restricciones de CORS.
        final uri = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/nearbysearch/json',
          {
            'location': '$lat,$lng',
            'radius': '1500',
            'key': SupabaseConfig.placesApiKey,
            'language': 'es',
          },
        );
        final response = await http.get(uri);
        if (!mounted || mySeq != _requestSeq) return;

        places = [];
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>? ?? [];
          places = results
              .take(8)
              .cast<Map<String, dynamic>>()
              .map((p) {
                final loc =
                    p['geometry']?['location'] as Map<String, dynamic>?;
                final name = p['name'] as String? ?? '';
                final vicinity = p['vicinity'] as String? ?? '';
                return <String, dynamic>{
                  'place_id': p['place_id'] as String? ?? '',
                  'description':
                      vicinity.isNotEmpty ? '$name, $vicinity' : name,
                  'main_text': name,
                  'secondary_text': vicinity,
                  if (loc != null) 'lat': (loc['lat'] as num).toDouble(),
                  if (loc != null) 'lng': (loc['lng'] as num).toDouble(),
                };
              })
              .where((p) => (p['place_id'] as String).isNotEmpty)
              .toList();
        }
      }

      if (!mounted || mySeq != _requestSeq) return;

      // Solo aplicar si el campo sigue vacío (usuario no empezó a escribir)
      if (places.isNotEmpty && _searchController.text.trim().isEmpty) {
        setState(() => _suggestions = places);
      }
    } catch (_) {
      // Error de red → fallback local ya visible.
    } finally {
      if (mounted && mySeq == _requestSeq) {
        setState(() => _isFetchingSuggestions = false);
      }
    }
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      if (_suggestions.isEmpty) {
        // Mostrar fallback local instantáneamente como placeholder
        setState(() => _suggestions =
            _fallbackPlaces.map((p) => Map<String, dynamic>.from(p)).toList());
      }
      // Si el campo está vacío, reemplazar con lugares cercanos reales
      if (_searchController.text.trim().isEmpty) {
        _fetchNearbyPlaces();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          setState(() => _suggestions = []);
        }
      });
    }
  }

  void _onSearchChanged() {
    // Fix: ignorar el cambio que dispara _selectPlace al asignar el texto
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }

    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      // Mostrar fallback como placeholder y reemplazar con cercanos reales
      setState(() => _suggestions =
          _fallbackPlaces.map((p) => Map<String, dynamic>.from(p)).toList());
      _fetchNearbyPlaces();
      return;
    }

    final local = _filterFallback(query);
    setState(() => _suggestions = local.isNotEmpty
        ? local
        : _fallbackPlaces.map((p) => Map<String, dynamic>.from(p)).toList());

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(query);
    });
  }

  /// Autocomplete al escribir.
  /// Web → Places JS API (sin CORS).
  /// Android/iOS → Places REST API directa.
  Future<void> _fetchSuggestions(String query) async {
    final mySeq = ++_requestSeq;
    if (mounted) setState(() => _isFetchingSuggestions = true);

    try {
      final lat = _currentPosition?.latitude ?? 32.5149;
      final lng = _currentPosition?.longitude ?? -117.0382;

      List<Map<String, dynamic>> results;

      if (kIsWeb) {
        // En web la REST API es bloqueada por CORS — usamos Places JS API.
        results = await fetchAutocompleteSuggestionsJS(query, lat, lng);
      } else {
        // Android/iOS → llamada REST directa.
        final uri = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/autocomplete/json',
          {
            'input': query,
            'key': SupabaseConfig.placesApiKey,
            'components': 'country:mx',
            'language': 'es',
            'location': '$lat,$lng',
            'radius': '50000',
          },
        );
        final response = await http.get(uri);

        // Descartar si llegó una request más nueva mientras esperábamos
        if (!mounted || mySeq != _requestSeq) return;

        results = [];
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final predictions = data['predictions'] as List<dynamic>? ?? [];
          results = predictions
              .cast<Map<String, dynamic>>()
              .map((p) => <String, dynamic>{
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
        }
      }

      if (!mounted || mySeq != _requestSeq) return;
      if (results.isNotEmpty) setState(() => _suggestions = results);
    } catch (_) {
      // Error de red → fallback local ya visible.
    } finally {
      if (mounted && mySeq == _requestSeq) {
        setState(() => _isFetchingSuggestions = false);
      }
    }
  }

  /// Llama a Places Details para obtener las coordenadas exactas de un
  /// resultado de la API (los fallback locales ya traen lat/lng embebidas).
  Future<Map<String, double>?> _fetchPlaceDetails(String placeId) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'key': SupabaseConfig.placesApiKey,
          'fields': 'geometry',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final location = data['result']?['geometry']?['location']
            as Map<String, dynamic>?;
        if (location != null) {
          return {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _selectPlace(Map<String, dynamic> suggestion) async {
    _debounce?.cancel();

    // Fix: evitar que el listener re-dispare la búsqueda cuando asignamos
    // el texto del campo programáticamente.
    _ignoreNextChange = true;

    setState(() {
      _suggestions = [];
      _searchController.text = suggestion['main_text'] as String;
    });
    _searchFocusNode.unfocus();

    double? destLat, destLng;

    if (suggestion.containsKey('lat') && suggestion.containsKey('lng')) {
      // Fallback local — coordenadas embebidas, sin llamada extra.
      destLat = (suggestion['lat'] as num).toDouble();
      destLng = (suggestion['lng'] as num).toDouble();
    } else {
      // Resultado real de Places API — resolver coordenadas vía Details.
      final coords =
          await _fetchPlaceDetails(suggestion['place_id'] as String);
      if (coords != null) {
        destLat = coords['lat'];
        destLng = coords['lng'];
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDetailsScreen(
          destination: suggestion['description'] as String,
          destinationLat: destLat,
          destinationLng: destLng,
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
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
    _positionSub?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(32.5149, -117.0382),
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentPosition!, zoom: 16),
                  ),
                );
              }
            },
            myLocationEnabled: !kIsWeb && _locationGranted,
            myLocationButtonEnabled: false,
            markers: kIsWeb ? _userMarker : {},
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Floating Input Field + Suggestions
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
                        horizontal: 4.0, vertical: 4.0),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
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
                                      color: Color(0xFF4285F4)),
                                ),
                              )
                            : const Icon(Icons.location_on,
                                color: Color(0xFF4285F4), size: 28),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Color(0xFF9AA0A6), size: 22),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _suggestions = _fallbackPlaces
                                      .map((p) =>
                                          Map<String, dynamic>.from(p))
                                      .toList());
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.mic_rounded,
                                    color: Color(0xFF4285F4), size: 28),
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
                      constraints: const BoxConstraints(maxHeight: 280),
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
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 48,
                              color: Color(0xFFF1F3F4)),
                          itemBuilder: (_, i) {
                            final s = _suggestions[i];
                            return InkWell(
                              onTap: () => _selectPlace(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.place_rounded,
                                        color: Color(0xFF4285F4), size: 20),
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
                                                fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((s['secondary_text'] as String)
                                              .isNotEmpty)
                                            Text(
                                              s['secondary_text'] as String,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _centerOnUser,
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
          ),

          // FAB — reportar barrera
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
                    setState(() => _suggestions = []);
                    _searchFocusNode.unfocus();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteDetailsScreen(
                          destination: destination,
                          // Sin coordenadas cuando el usuario escribe
                          // manualmente sin seleccionar una sugerencia.
                        ),
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
