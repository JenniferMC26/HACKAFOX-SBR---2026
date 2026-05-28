import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(20)),
      child: Text('$level / 10',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: _textColor())));
  }

  Color _bgColor() {
    if (level <= 3) return const Color(0xFFE6F4EA);
    if (level <= 6) return const Color(0xFFFEF7E0);
    return const Color(0xFFFDECEA);
  }

  Color _textColor() {
    if (level <= 3) return AppColors.success;
    if (level <= 6) return AppColors.warning;
    return AppColors.danger;
  }
}
