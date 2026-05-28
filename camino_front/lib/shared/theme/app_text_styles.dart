import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const screenTitle = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5);

  static const sectionTitle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w800);

  static const cardTitle = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black);

  static const body = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87);

  static const bodyGrey = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey);

  static const label = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87);

  static const labelGrey = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey);

  static const caption = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey);
}
