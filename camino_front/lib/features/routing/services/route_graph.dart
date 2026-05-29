import 'package:google_maps_flutter/google_maps_flutter.dart';

// Representa un segmento de calle (cluster del CSV)
class RoadSegment {
  final int clusterId;
  final double avgScore;
  final LatLng centroid;
  final List<LatLng> points;

  const RoadSegment({
    required this.clusterId,
    required this.avgScore,
    required this.centroid,
    required this.points,
  });
}

// Representa una intersección entre segmentos
class Intersection {
  final String id;
  final LatLng position;
  final List<int> clusterIds;

  const Intersection({
    required this.id,
    required this.position,
    required this.clusterIds,
  });
}

// Arista del grafo: conexión entre dos intersecciones
class RouteEdge {
  final String fromId;
  final String toId;
  final int clusterId;
  final double score;
  final double distanceMeters;
  final List<LatLng> pathPoints;

  const RouteEdge({
    required this.fromId,
    required this.toId,
    required this.clusterId,
    required this.score,
    required this.distanceMeters,
    required this.pathPoints,
  });
}

// Resultado del algoritmo de ruteo
class RouteResult {
  final List<LatLng> polylinePoints;
  final double totalDistance;
  final double avgAccessibility;
  final bool found;
  final int segmentsCount;

  const RouteResult({
    required this.polylinePoints,
    required this.totalDistance,
    required this.avgAccessibility,
    required this.found,
    required this.segmentsCount,
  });

  factory RouteResult.notFound() => const RouteResult(
        polylinePoints: [],
        totalDistance: 0,
        avgAccessibility: 0,
        found: false,
        segmentsCount: 0,
      );
}
