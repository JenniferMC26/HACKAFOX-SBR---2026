import 'dart:async';
import 'dart:js' as js;

/// Llama a Places Nearby Search usando la Places JS API del browser.
/// No tiene restricción de CORS porque corre dentro del contexto del navegador.
/// Requiere que index.html cargue Maps JS API con &libraries=places.
Future<List<Map<String, dynamic>>> fetchNearbyPlacesJS(
    double lat, double lng) async {
  final completer = Completer<List<Map<String, dynamic>>>();

  try {
    final google = js.context['google'];
    if (google == null) return [];

    final maps = google['maps'] as js.JsObject;
    final places = maps['places'] as js.JsObject;

    // PlacesService requiere un elemento DOM para mostrar las atribuciones.
    final div = js.context['document']
        .callMethod('createElement', ['div']) as js.JsObject;
    final service =
        js.JsObject(places['PlacesService'] as js.JsFunction, [div]);

    // Construir la request como objeto JS puro
    final latLng =
        js.JsObject(maps['LatLng'] as js.JsFunction, [lat, lng]);
    final request =
        js.JsObject(js.context['Object'] as js.JsFunction, []);
    request['location'] = latLng;
    request['radius'] = 1500;
    request['language'] = 'es';

    service.callMethod('nearbySearch', [
      request,
      js.allowInterop((dynamic results, dynamic status) {
        try {
          if (results == null) {
            completer.complete([]);
            return;
          }
          final jsResults = results as js.JsArray;
          final list = <Map<String, dynamic>>[];
          final limit = jsResults.length < 8 ? jsResults.length : 8;

          for (var i = 0; i < limit; i++) {
            final p = jsResults[i] as js.JsObject;
            final name = p['name'] as String? ?? '';
            final vicinity = p['vicinity'] as String? ?? '';
            final placeId = p['place_id'] as String? ?? '';
            if (name.isEmpty || placeId.isEmpty) continue;

            double? pLat, pLng;
            try {
              final geo = p['geometry'] as js.JsObject?;
              final loc = geo?['location'] as js.JsObject?;
              if (loc != null) {
                pLat = (loc.callMethod('lat', []) as num).toDouble();
                pLng = (loc.callMethod('lng', []) as num).toDouble();
              }
            } catch (_) {}

            list.add({
              'place_id': placeId,
              'description':
                  vicinity.isNotEmpty ? '$name, $vicinity' : name,
              'main_text': name,
              'secondary_text': vicinity,
              if (pLat != null) 'lat': pLat,
              if (pLng != null) 'lng': pLng,
            });
          }
          completer.complete(list);
        } catch (_) {
          completer.complete([]);
        }
      }),
    ]);
  } catch (_) {
    completer.complete([]);
  }

  return completer.future;
}

/// Llama a Places Autocomplete usando la Places JS API del browser.
/// Sin CORS, sin restricciones de origen.
Future<List<Map<String, dynamic>>> fetchAutocompleteSuggestionsJS(
    String query, double lat, double lng) async {
  final completer = Completer<List<Map<String, dynamic>>>();

  try {
    final google = js.context['google'];
    if (google == null) return [];

    final maps = google['maps'] as js.JsObject;
    final places = maps['places'] as js.JsObject;

    final service =
        js.JsObject(places['AutocompleteService'] as js.JsFunction, []);

    final latLng =
        js.JsObject(maps['LatLng'] as js.JsFunction, [lat, lng]);

    final restrictions =
        js.JsObject(js.context['Object'] as js.JsFunction, []);
    restrictions['country'] = 'mx';

    final request =
        js.JsObject(js.context['Object'] as js.JsFunction, []);
    request['input'] = query;
    request['componentRestrictions'] = restrictions;
    request['language'] = 'es';
    request['location'] = latLng;
    request['radius'] = 50000;

    service.callMethod('getPlacePredictions', [
      request,
      js.allowInterop((dynamic predictions, dynamic status) {
        try {
          if (predictions == null) {
            completer.complete([]);
            return;
          }
          final jsPredictions = predictions as js.JsArray;
          final list = <Map<String, dynamic>>[];

          for (var i = 0; i < jsPredictions.length; i++) {
            final p = jsPredictions[i] as js.JsObject;
            final placeId = p['place_id'] as String? ?? '';
            final description = p['description'] as String? ?? '';
            if (placeId.isEmpty) continue;

            String mainText = description;
            String secondaryText = '';
            try {
              final sf = p['structured_formatting'] as js.JsObject?;
              if (sf != null) {
                mainText = sf['main_text'] as String? ?? description;
                secondaryText = sf['secondary_text'] as String? ?? '';
              }
            } catch (_) {}

            list.add({
              'place_id': placeId,
              'description': description,
              'main_text': mainText,
              'secondary_text': secondaryText,
            });
          }
          completer.complete(list);
        } catch (_) {
          completer.complete([]);
        }
      }),
    ]);
  } catch (_) {
    completer.complete([]);
  }

  return completer.future;
}
