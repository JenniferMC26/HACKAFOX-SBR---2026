import 'package:flutter/material.dart';
import 'package:camino_front/features/routing/screens/navigation_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  const RouteDetailsScreen({
    super.key,
    this.destination = 'IMSS Clínica 1 — Tijuana',
    this.destinationLat,
    this.destinationLng,
  });

  final String destination;
  /// Latitud del destino resuelto por Places Details (null si no disponible).
  final double? destinationLat;
  /// Longitud del destino resuelto por Places Details (null si no disponible).
  final double? destinationLng;

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  bool _isLoading = true;
  String _foundLocation = "";
  String _selectedMethod = "Estandar";

  @override
  void initState() {
    super.initState();
    _simulateServerFetch();
  }

  Future<void> _simulateServerFetch() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _foundLocation = widget.destination;
      _isLoading = false;
    });
  }

  Map<String, Map<String, String>> get _routeDetailsData => {
    "Estandar": {
      "time": "18 min",
      "distance": "1.4 km",
      "desc":
          "Ruta directa por Av. Revolución. Incluye dos cruces peatonales con semáforo y banquetas en buen estado.",
    },
    "Silla de ruedas": {
      "time": "24 min",
      "distance": "1.8 km",
      "desc":
          "Ruta accesible por Calle 3ra. Evita el desnivel de Av. Constitución. Rampas verificadas en todos los cruces.",
    },
    "Baston": {
      "time": "21 min",
      "distance": "1.6 km",
      "desc":
          "Ruta con pavimento táctil por Blvd. Agua Caliente. Semáforos con señal de audio en intersecciones principales.",
    },
    "Andadera": {
      "time": "26 min",
      "distance": "1.5 km",
      "desc":
          "Ruta de baja fatiga por Av. Sánchez Taboada. Bancos de descanso cada 200 metros. Sin pendientes pronunciadas.",
    },
  };

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
      ),
      body: _isLoading ? _buildLoadingView() : _buildSelectionView(),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Encontrando rutas...',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Consultando el mapa...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4285F4),
                strokeWidth: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    final currentData = _routeDetailsData[_selectedMethod]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _foundLocation,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '¿Cómo te desplazas?',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMobilityCard("Estandar", Icons.directions_walk_rounded),
              _buildMobilityCard(
                "Silla de ruedas",
                Icons.accessible_forward_rounded,
              ),
              _buildMobilityCard("Baston", Icons.blind_rounded),
              _buildMobilityCard("Andadera", Icons.assist_walker_rounded),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      avatar: const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFF9AB00),
                      ),
                      label: const Text("2 alertas en ruta"),
                      backgroundColor: const Color(0xFFFEF7E0),
                      side: BorderSide.none,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Color(0xFF34A853),
                      ),
                      label: const Text("Ruta validada"),
                      backgroundColor: const Color(0xFFE6F4EA),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      currentData["time"]!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '(${currentData["distance"]!})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F3F4)),
                const SizedBox(height: 16),
                Text(
                  currentData["desc"]!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: Semantics(
                  label: "Iniciar navegación hacia $_foundLocation",
                  button: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NavigationScreen(
                          destination: _foundLocation,
                          // Pasar coordenadas resueltas para auto-calcular ruta
                          destinationLat: widget.destinationLat,
                          destinationLng: widget.destinationLng,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Iniciar navegación',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilityCard(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Semantics(
      label: "Seleccionar ruta para ${method.toLowerCase()}",
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4285F4) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4285F4)
                      : Colors.grey.shade200,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black87,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              method,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF4285F4)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
