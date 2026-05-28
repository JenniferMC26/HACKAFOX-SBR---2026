import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class RouteInfoCard extends StatelessWidget {
  const RouteInfoCard({
    super.key,
    required this.time,
    required this.distance,
    required this.description,
    this.alertCount = 2,
    this.isValidated = true,
  });

  final String time;
  final String distance;
  final String description;
  final int alertCount;
  final bool isValidated;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Chip(
                avatar: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: const Color(0xFFF9AB00),
                ),
                label: Text('$alertCount alertas en ruta'),
                backgroundColor: const Color(0xFFFEF7E0),
                side: BorderSide.none,
              ),
              const SizedBox(width: 8),
              if (isValidated)
                Chip(
                  avatar: Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  label: const Text('Ruta validada'),
                  backgroundColor: const Color(0xFFE6F4EA),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '($distance)',
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
            description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
