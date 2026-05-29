import 'package:flutter/material.dart';

class BarrierConfirmedScreen extends StatelessWidget {
  const BarrierConfirmedScreen({
    super.key,
    this.barrierType = "Rampa destruida",
    this.severityLevel = 7,
    this.location = "Calle 3ra, Centro Tijuana",
    this.ticketId,
  });

  final String barrierType;
  final int severityLevel;
  final String location;
  final String? ticketId;

  Widget _buildRow(IconData icon, String label, String value, Color iconColor) {
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

  Widget _divider() {
    return const Divider(height: 1, color: Color(0xFFF1F3F4));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Reporte enviado",
          style: TextStyle(
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECCIÓN: Confirmación visual
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF34A853),
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "¡Reporte enviado!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "La comunidad ya puede ver esta barrera en el mapa.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // SECCIÓN: Card resumen
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Resumen del reporte",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF34A853),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRow(
                      Icons.category_rounded,
                      "Tipo",
                      barrierType,
                      Colors.black87,
                    ),
                    _divider(),
                    _buildRow(
                      Icons.bar_chart_rounded,
                      "Severidad",
                      "$severityLevel / 10",
                      severityLevel >= 7
                          ? const Color(0xFFEA4335)
                          : const Color(0xFFFBBC04),
                    ),
                    _divider(),
                    _buildRow(
                      Icons.location_on_rounded,
                      "Ubicación",
                      location,
                      const Color(0xFF4285F4),
                    ),
                    _divider(),
                    _buildRow(
                      Icons.people_rounded,
                      "Visible para",
                      "Todos los usuarios",
                      const Color(0xFF34A853),
                    ),
                    _divider(),
                    _buildRow(
                      Icons.update_rounded,
                      "Estado",
                      "Activo en el mapa",
                      const Color(0xFF34A853),
                    ),
                    if (ticketId != null) ...[
                      _divider(),
                      _buildRow(
                        Icons.confirmation_number_rounded,
                        "Ticket cívico",
                        ticketId!,
                        const Color(0xFF4285F4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECCIÓN: Chips de impacto
              const Row(
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF34A853),
                    ),
                    label: Text("Mapa actualizado"),
                    backgroundColor: Color(0xFFE6F4EA),
                    side: BorderSide.none,
                  ),
                  SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFFBBC04),
                    ),
                    label: Text("Severidad alta"),
                    backgroundColor: Color(0xFFFEF7E0),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SECCIÓN: Impacto social
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFF34A853),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Este reporte ayuda a 170,000 personas con movilidad reducida en Tijuana a planear rutas más seguras.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2D7A4A),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // SECCIÓN: Botones de acción
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: "Ver la barrera reportada en el mapa principal",
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map_rounded),
                        label: const Text(
                          "Ver en el mapa",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4285F4),
                          side: const BorderSide(color: Color(0xFF4285F4)),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: "Continuar la navegación hacia el destino",
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text(
                          "Seguir navegando",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 56),
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
            ],
          ),
        ),
      ),
    );
  }
}
