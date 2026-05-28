import 'package:flutter/material.dart';
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

  Future<void> _runAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _state = _ReportState.result;
      _barrierType = "Rampa destruida";
      _severityLevel = 7;
      _analysisDescription =
          "Daño estructural en rampa de acceso peatonal. Alta severidad para usuarios de silla de ruedas y andadera. Requiere intervención municipal. Estimado: permanente.";
    });
  }

  Color _severityColor() {
    if (_severityLevel <= 3) return const Color(0xFF34A853);
    if (_severityLevel <= 6) return const Color(0xFFFBBC04);
    return const Color(0xFFEA4335);
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
                onTap: () {
                  setState(() {
                    _photoSelected = true;
                  });
                },
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
                              "Toca para agregar foto",
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text("Cámara"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4285F4),
                        side: const BorderSide(color: Color(0xFF4285F4)),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onPressed: () => setState(() => _photoSelected = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text("Galería"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4285F4),
                        side: const BorderSide(color: Color(0xFF4285F4)),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onPressed: () => setState(() => _photoSelected = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: "Analizar foto con inteligencia artificial",
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
                        ? () {
                            setState(() => _state = _ReportState.analyzing);
                            _runAnalysis();
                          }
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
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_rounded,
                      size: 40,
                      color: Color(0xFF9AA0A6),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Vista previa de la imagen",
                      style: TextStyle(fontSize: 14, color: Color(0xFF9AA0A6)),
                    ),
                  ],
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
                    "Analizado por Gemini Vision",
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
                    Row(
                      children: [
                        const Chip(
                          avatar: Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Color(0xFFFBBC04),
                          ),
                          label: Text("Riesgo alto"),
                          backgroundColor: Color(0xFFFEF7E0),
                          side: BorderSide.none,
                        ),
                        const SizedBox(width: 8),
                        const Chip(
                          avatar: Icon(
                            Icons.accessible_forward_rounded,
                            size: 14,
                            color: Color(0xFF4285F4),
                          ),
                          label: Text("Silla de ruedas"),
                          backgroundColor: Color(0xFFE8F0FE),
                          side: BorderSide.none,
                        ),
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
              const Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFEA4335),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Capturada automáticamente · Centro, TJ",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BarrierConfirmedScreen(
                          barrierType: _barrierType,
                          severityLevel: _severityLevel,
                        ),
                      ),
                    ),
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
