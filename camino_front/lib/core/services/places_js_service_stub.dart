/// Stub para Android/iOS — las funciones devuelven lista vacía.
/// El código en starting_screen.dart usa kIsWeb para no llamar esto en mobile,
/// pero el stub evita errores de compilación.

Future<List<Map<String, dynamic>>> fetchNearbyPlacesJS(
        double lat, double lng) async =>
    [];

Future<List<Map<String, dynamic>>> fetchAutocompleteSuggestionsJS(
        String query, double lat, double lng) async =>
    [];
