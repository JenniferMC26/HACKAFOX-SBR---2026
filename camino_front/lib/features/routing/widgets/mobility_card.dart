import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class MobilityCard extends StatelessWidget {
  const MobilityCard({
    super.key,
    required this.method,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String method;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Seleccionar ruta para ${method.toLowerCase()}',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
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
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
