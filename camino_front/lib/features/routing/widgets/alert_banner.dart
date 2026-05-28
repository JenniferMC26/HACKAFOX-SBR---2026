import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.message,
    this.onAlternativeRoute,
  });
  final String message;
  final VoidCallback? onAlternativeRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFFBBC04), width: 4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFFBBC04), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Barrera detectada',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(message,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ])),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onAlternativeRoute ?? () {},
            child: const Text('Ver ruta alternativa',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF4285F4))))),
      ]));
  }
}
