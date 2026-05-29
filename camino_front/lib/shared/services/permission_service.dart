import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      return await _requestWebLocation();
    }
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    if (kIsWeb) return;
    await openAppSettings();
  }

  static Future<bool> _requestWebLocation() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return await _requestWebMicrophone();
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  static Future<bool> _requestWebMicrophone() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }
}
