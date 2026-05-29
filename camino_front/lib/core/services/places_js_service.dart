/// Router de importación condicional.
/// En web compila places_js_service_web.dart (dart:js).
/// En Android/iOS compila el stub vacío.
export 'places_js_service_stub.dart'
    if (dart.library.html) 'places_js_service_web.dart';
