import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

enum ChipType { alert, validated, info }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.type});

  final String label;
  final ChipType type;

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return Chip(
      avatar: Icon(
        config['icon'] as IconData,
        size: 14,
        color: config['iconColor'] as Color,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: config['iconColor'] as Color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: config['bgColor'] as Color,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Map<String, dynamic> _config() => switch (type) {
    ChipType.alert => {
      'icon': Icons.warning_amber_rounded,
      'iconColor': const Color(0xFFF9AB00),
      'bgColor': const Color(0xFFFEF7E0),
    },
    ChipType.validated => {
      'icon': Icons.verified_rounded,
      'iconColor': AppColors.success,
      'bgColor': const Color(0xFFE6F4EA),
    },
    ChipType.info => {
      'icon': Icons.info_rounded,
      'iconColor': AppColors.primary,
      'bgColor': const Color(0xFFE8F0FE),
    },
  };
}
