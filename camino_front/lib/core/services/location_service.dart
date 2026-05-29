import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  LocationService._();

  // Fallback: centro de Tijuana
  static const LatLng _tijuanaCenter = LatLng(32.5149, -117.0382);

  /// Retorna la posición GPS real del usuario en Android Y web.
  /// geolocator ^13 soporta la Geolocation API del navegador de forma nativa.
  /// Si no hay permiso o el servicio está apagado, retorna [_tijuanaCenter].
  static Future<LatLng> getCurrentPosition() async {
    try {
      // 1. Verificar / solicitar permiso (en web dispara el dialog del browser).
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _tijuanaCenter;
      }

      // 2. Obtener posición (timeout 10s — web puede tardar más que Android).
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
      );

      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return _tijuanaCenter;
    }
  }

  /// Stream de actualizaciones de posición (cada 10 m o 5 s).
  static Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((pos) => LatLng(pos.latitude, pos.longitude));
  }
}
