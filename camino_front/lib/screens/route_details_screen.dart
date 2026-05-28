import 'package:flutter/material.dart';

class RouteDetailsScreen extends StatefulWidget {
  const RouteDetailsScreen({super.key});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  // State variables
  bool _isLoading = true;
  String _foundLocation = "";
  String _selectedMethod = "Estandar";

  @override
  void initState() {
    super.initState();
    _simulateServerFetch();
  }

  // 1. DUMMY SERVER REQUEST
  // Waits 2 seconds, selects a placeholder destination, and changes screen state
  Future<void> _simulateServerFetch() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check if the user hasn't already pressed back and left the screen
    if (!mounted) return;

    setState(() {
      _foundLocation = "Santiago de Compostela Cathedral";
      _isLoading = false; // This triggers the transition to the selection view
    });
  }

  // Helper dictionary to dynamically swap route data based on selection
  Map<String, Map<String, String>> get _routeDetailsData => {
    "Estandar": {
      "time": "11 min",
      "distance": "0.9 km",
      "desc":
          "Ruta directa más corto. Incluye aceras estándar, dos cruces peatonales y un tramo de escaleras de arquitectura pública.",
    },
    "Silla de ruedas": {
      "time": "16 min",
      "distance": "1.3 km",
      "desc":
          "Ruta optimizada sin obstáculos. Evita adoquines y pendientes pronunciadas. Cuenta con rebajes 100% accesibles y cruces con rampas automatizadas.",
    },
    "Baston": {
      "time": "14 min",
      "distance": "1.1 km",
      "desc":
          "Ruta prioritaria con pavimento táctil. Senderos guía continuos totalmente mapeados con semáforos asistidos por audio en las intersecciones principales.",
    },
    "Andadera": {
      "time": "18 min",
      "distance": "1.0 km",
      "desc":
          "Ruta de baja fatiga. Evita pendientes pronunciadas y terrenos irregulares. Destaca bancos de descanso regulares espaciados cada 150 metros.",
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
      // Automatically switch layout view based on whether the server request finished
      body: _isLoading ? _buildLoadingView() : _buildSelectionView(),
    );
  }

  // =======================================================================
  // VIEW 1: LOADING STATE (Original Layout + Progress Indicator)
  // =======================================================================
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
                color: Colors.black,
                strokeWidth: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // VIEW 2: METHOD SELECTION & DYNAMIC DETAILS (Google-Style)
  // =======================================================================
  Widget _buildSelectionView() {
    final currentData = _routeDetailsData[_selectedMethod]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination Title Banner
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
            'Selecciona tu Asistencia de movilidad:',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Horizontal selector grid for mobility options
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

          // Dynamic Route details container box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
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
                    Text(
                      currentData["time"]!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
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

          // Primary Action Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Final confirmation action
                  },
                  child: const Text(
                    'Start Guidance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget factory to render the selectable round cards
  Widget _buildMobilityCard(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod =
              method; // Tapping triggers state change & layout updates
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black87,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            method,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
