import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class PhotoPreviewCard extends StatelessWidget {
  const PhotoPreviewCard({
    super.key,
    required this.isSelected,
    required this.onTap,
  });
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F4EA) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.success : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isSelected
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Foto lista para analizar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 48,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca para agregar foto',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
