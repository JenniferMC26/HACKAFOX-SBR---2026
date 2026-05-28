import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
    this.height = 56,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
      ? ElevatedButton.icon(
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: _style(),
          onPressed: onPressed)
      : ElevatedButton(
          style: _style(),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));
    return isFullWidth
      ? SizedBox(width: double.infinity, height: height, child: button)
      : SizedBox(height: height, child: button);
  }

  ButtonStyle _style() => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)));
}
