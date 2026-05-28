import 'package:flutter/material.dart';
import 'package:camino_front/shared/theme/app_colors.dart';

class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({
    super.key,
    required this.barrierType,
    required this.severityLevel,
    required this.description,
  });
  final String barrierType;
  final int severityLevel;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildRow('Tipo de barrera', barrierType,
          Icons.warning_rounded, Colors.black87),
        const Divider(color: Color(0xFFF1F3F4)),
        _buildRow('Severidad', '$severityLevel / 10',
          Icons.bar_chart_rounded, _severityColor()),
        const Divider(color: Color(0xFFF1F3F4)),
        Row(children: [
          Chip(
            avatar: Icon(Icons.warning_amber_rounded, size: 14,
              color: AppColors.warning),
            label: const Text('Riesgo alto'),
            backgroundColor: const Color(0xFFFEF7E0),
            side: BorderSide.none),
          const SizedBox(width: 8),
          Chip(
            avatar: Icon(Icons.accessible_forward_rounded, size: 14,
              color: AppColors.primary),
            label: const Text('Silla de ruedas'),
            backgroundColor: const Color(0xFFE8F0FE),
            side: BorderSide.none),
        ]),
        const SizedBox(height: 12),
        Text(description,
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
      ]));
  }

  Widget _buildRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Text(label,
          style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const Spacer(),
        Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: Colors.black87)),
      ]));
  }

  Color _severityColor() {
    if (severityLevel <= 3) return AppColors.success;
    if (severityLevel <= 6) return AppColors.warning;
    return AppColors.danger;
  }
}
