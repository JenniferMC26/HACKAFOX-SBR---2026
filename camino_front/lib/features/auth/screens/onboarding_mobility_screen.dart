import 'package:flutter/material.dart';
import 'package:camino_front/features/auth/screens/onboarding_emergency_screen.dart';

class OnboardingMobilityScreen extends StatefulWidget {
  const OnboardingMobilityScreen({super.key});

  @override
  State<OnboardingMobilityScreen> createState() =>
      _OnboardingMobilityScreenState();
}

class _OnboardingMobilityScreenState extends State<OnboardingMobilityScreen> {
  String? _selectedMobility;
  final List<String> _additionalOptions = [];

  bool get _isAdultoMayor => _selectedMobility == 'Adulto mayor';

  static const List<Map<String, Object>> _mobilityOptions = [
    {
      'label': 'Estándar',
      'icon': Icons.directions_walk_rounded,
      'desc': 'Camino sin ayuda',
    },
    {
      'label': 'Silla de ruedas',
      'icon': Icons.accessible_forward_rounded,
      'desc': 'Usuario de silla',
    },
    {
      'label': 'Bastón',
      'icon': Icons.blind_rounded,
      'desc': 'Apoyo con bastón',
    },
    {
      'label': 'Andadera',
      'icon': Icons.assist_walker_rounded,
      'desc': 'Apoyo con andadera',
    },
    {
      'label': 'Adulto mayor',
      'icon': Icons.elderly_rounded,
      'desc': 'Puede combinar opciones',
    },
  ];

  static const List<String> _extraOptions = ['Bastón', 'Andadera', 'Silla de ruedas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECCIÓN: Indicador de progreso
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.5,
                        backgroundColor: Color(0xFFE0E0E0),
                        color: Color(0xFF4285F4),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '1 de 2',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECCIÓN: Header
              const Text(
                '¿Cómo te desplazas?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esto nos ayuda a encontrar las rutas más seguras para ti.',
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),

              // SECCIÓN: Grid de opciones de movilidad
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _mobilityOptions.length,
                  itemBuilder: (context, index) {
                    final option = _mobilityOptions[index];
                    final label = option['label'] as String;
                    final icon = option['icon'] as IconData;
                    final desc = option['desc'] as String;
                    final isSelected = _selectedMobility == label;

                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedMobility = label;
                        _additionalOptions.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F0FE)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4285F4)
                                : const Color(0xFFE0E0E0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? const Color(0xFF4285F4)
                                  : const Color(0xFF9AA0A6),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF4285F4)
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // SECCIÓN: Opciones adicionales para adulto mayor
              if (_isAdultoMayor) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF7E0),
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      left: BorderSide(color: Color(0xFFFBBC04), width: 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_rounded,
                            color: Color(0xFFFBBC04),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selecciona apoyos adicionales que uses (opcional)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extraOptions.map((option) {
                          final isExtra = _additionalOptions.contains(option);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (isExtra) {
                                _additionalOptions.remove(option);
                              } else {
                                _additionalOptions.add(option);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isExtra
                                    ? const Color(0xFF4285F4)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isExtra
                                      ? const Color(0xFF4285F4)
                                      : const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isExtra ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // SECCIÓN: Botón continuar
              Semantics(
                button: true,
                label: 'Continuar al siguiente paso del registro',
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMobility != null
                          ? const Color(0xFF4285F4)
                          : const Color(0xFFE0E0E0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    onPressed: _selectedMobility == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OnboardingEmergencyScreen(
                                  mobility: _selectedMobility!,
                                  additionalOptions: _additionalOptions,
                                ),
                              ),
                            ),
                    child: const Text(
                      'Continuar →',
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
      ),
          ),
        ),
      ),
    );
  }
}
