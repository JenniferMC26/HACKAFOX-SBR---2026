import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camino_front/core/services/report_service.dart';
import 'package:camino_front/features/reporting/screens/barrier_confirmed_screen.dart';

enum _ReportState { takingPhoto, analyzing, result }

class ReportBarrierScreen extends StatefulWidget {
  const ReportBarrierScreen({super.key});

  @override
  State<ReportBarrierScreen> createState() => _ReportBarrierScreenState();
}

class _ReportBarrierScreenState extends State<ReportBarrierScreen> {
  _ReportState _state = _ReportState.takingPhoto;
  String _barrierType = "";
  int _severityLevel = 0;
  String _analysisDescription = "";
  bool _photoSelected = false;
  XFile? _pickedImage;
  Uint8List? _imageBytes;
  GeminiAnalysis? _analysis;
  Position? _currentPosition;
  final ImagePicker _picker = ImagePicker();

  Future<void> _runAnalysis() async {
    if (_imageBytes == null) return;
    setState(() => _state = _ReportState.analyzing);

    try {
      final locationFuture = _getCurrentLocation();
      final analysis =
          await ReportService.analyzeWithGemini(imageBytes: _imageBytes!);
      _currentPosition = await locationFuture;

      if (!mounted) return;
      setState(() {
        _state = _ReportState.result;
        _analysis = analysis;
        _barrierType = analysis.barrierTypeDisplay;
        _severityLevel = analysis.severity;
        _analysisDescription = analysis.description;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _ReportState.takingPhoto);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al analizar la imagen. Intenta de nuevo.'),
          backgroundColor: const Color(0xFFEA4335),
        ),
      );
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (_analysis == null || _pickedImage == null) return;
    final lat = _currentPosition?.latitude ?? 32.5266;
    final lng = _currentPosition?.longitude ?? -117.0382;

    try {
      final result = await ReportService.submitReport(
        photoPath: _pickedImage!.path,
        photoBytes: _imageBytes!,
        lat: lat,
        lng: lng,
        analysis: _analysis!,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarrierConfirmedScreen(
            barrierType: _barrierType,
            severityLevel: _severityLevel,
            ticketId: result['ticketId'] as String?,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reporte: $e'),
          backgroundColor: const Color(0xFFEA4335),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    // PERMISO EN ANDROID
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'PASO necesita acceso a la cámara '
                'para fotografiar la barrera'),
            backgroundColor: const Color(0xFFEA4335),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    // PERMISO EN WEB — el navegador lo pide automáticamente
    if (kIsWeb) {
      final granted = await _requestWebCameraPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Permite el acceso a la cámara '
                'en tu navegador para continuar'),
            backgroundColor: const Color(0xFFEA4335),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    // ABRIR CÁMARA — igual en web y Android
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _pickedImage = photo;
          _imageBytes = bytes;
          _photoSelected = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No se pudo acceder a la cámara: '
              'verifica los permisos del navegador'),
          backgroundColor: const Color(0xFFEA4335),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<bool> _requestWebCameraPermission() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  Color _severityColor() {
    if (_severityLevel <= 3) return const Color(0xFF34A853);
    if (_severityLevel <= 6) return const Color(0xFFFBBC04);
    return const Color(0xFFEA4335);
  }

  /// Chip de severidad dinámico según nivel.
  Widget _buildSeverityChip() {
    final String label;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (_severityLevel <= 3) {
      label = 'Riesgo bajo';
      bg    = const Color(0xFFE6F4EA);
      fg    = const Color(0xFF34A853);
      icon  = Icons.check_circle_outline_rounded;
    } else if (_severityLevel <= 6) {
      label = 'Riesgo medio';
      bg    = const Color(0xFFFEF7E0);
      fg    = const Color(0xFFFBBC04);
      icon  = Icons.warning_amber_rounded;
    } else {
      label = 'Riesgo alto';
      bg    = const Color(0xFFFDECEA);
      fg    = const Color(0xFFEA4335);
      icon  = Icons.warning_rounded;
    }

    return Chip(
      avatar: Icon(icon, size: 14, color: fg),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      side: BorderSide.none,
    );
  }

  /// Chips de perfiles afectados basados en el análisis real.
  List<Widget> _buildProfileChips() {
    if (_analysis == null || _analysis!.affectedProfiles.isEmpty) return [];

    const profileMap = <String, Map<String, dynamic>>{
      'wheelchair': {
        'label': 'Silla de ruedas',
        'icon': Icons.accessible_forward_rounded,
        'color': Color(0xFF4285F4),
        'bg': Color(0xFFE8F0FE),
      },
      'elderly': {
        'label': 'Adulto mayor',
        'icon': Icons.elderly_rounded,
        'color': Color(0xFF9C27B0),
        'bg': Color(0xFFF3E5F5),
      },
      'cane': {
        'label': 'Bastón',
        'icon': Icons.accessibility_new_rounded,
        'color': Color(0xFF795548),
        'bg': Color(0xFFEFEBE9),
      },
      'stroller': {
        'label': 'Carriola',
        'icon': Icons.child_friendly_rounded,
        'color': Color(0xFF00897B),
        'bg': Color(0xFFE0F2F1),
      },
    };

    return _analysis!.affectedProfiles
        .where(profileMap.containsKey)
        .map((profile) {
          final data = profileMap[profile]!;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Icon(
                data['icon'] as IconData,
                size: 14,
                color: data['color'] as Color,
              ),
              label: Text(
                data['label'] as String,
                style: TextStyle(
                  color: data['color'] as Color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: data['bg'] as Color,
              side: BorderSide.none,
            ),
          );
        })
        .toList();
  }

  /// Texto de ubicación usando GPS real, o fallback si no está disponible.
  String _locationText() {
    if (_currentPosition == null) return 'Ubicación no disponible';
    final lat = _currentPosition!.latitude.toStringAsFixed(5);
    final lng = _currentPosition!.longitude.toStringAsFixed(5);
    return '$lat, $lng';
  }

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (_state == _ReportState.takingPhoto) {
      appBarTitle = "Reportar barrera";
    } else if (_state == _ReportState.analyzing) {
      appBarTitle = "Analizando foto...";
    } else {
      appBarTitle = "Confirmar reporte";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_state == _ReportState.takingPhoto) {
      // ESTADO: takingPhoto
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "¿Qué obstáculo encontraste?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Toma una foto. La IA identifica la barrera automáticamente.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _takePhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _photoSelected
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _photoSelected
                          ? const Color(0xFF34A853)
                          : const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: _photoSelected
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 48,
                              color: Color(0xFF34A853),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Foto lista para analizar",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF34A853),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              size: 48,
                              color: Color(0xFF9AA0A6),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Toca para abrir la cámara",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text("Tomar foto"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4285F4),
                    side: const BorderSide(color: Color(0xFF4285F4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32))),
                  onPressed: _takePhoto)),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: "Tomar foto con la cámara y analizar con inteligencia artificial",
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
                    onPressed: _photoSelected
                        ? _runAnalysis
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Primero agrega una foto"),
                                backgroundColor: Color(0xFF4285F4),
                              ),
                            );
                          },
                    child: const Text(
                      "Analizar con IA →",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_state == _ReportState.analyzing) {
      // ESTADO: analyzing
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4285F4), strokeWidth: 4),
            SizedBox(height: 24),
            Text(
              "Gemini Vision está analizando...",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Identificando barrera y nivel de riesgo",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // ESTADO: result
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: const Color(0xFFF1F3F4),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_rounded,
                                size: 40, color: Color(0xFF9AA0A6)),
                            SizedBox(height: 6),
                            Text(
                              'Sin foto',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF9AA0A6)),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF4285F4),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Analizado por Llama Vision",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(
                      "Tipo de barrera",
                      _barrierType,
                      Icons.warning_rounded,
                      Colors.black87,
                    ),
                    const Divider(color: Color(0xFFF1F3F4)),
                    _buildResultRow(
                      "Severidad",
                      "$_severityLevel / 10",
                      Icons.bar_chart_rounded,
                      _severityColor(),
                    ),
                    const Divider(color: Color(0xFFF1F3F4)),
                    Wrap(
                      spacing: 0,
                      runSpacing: 8,
                      children: [
                        _buildSeverityChip(),
                        ..._buildProfileChips(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysisDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFEA4335),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Capturada automáticamente · ${_locationText()}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: "Enviar reporte de barrera a la comunidad",
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "Enviar reporte a la comunidad",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    onPressed: _submitReport,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
