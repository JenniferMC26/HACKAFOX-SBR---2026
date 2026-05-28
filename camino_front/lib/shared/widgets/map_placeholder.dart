import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, this.label = 'Cargando mapa de Tijuana...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mapBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_rounded,
              size: 80,
              color: AppColors.secondary.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
