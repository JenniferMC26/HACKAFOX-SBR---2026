import 'dart:math';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_graph.dart';

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  Map<int, RoadSegment> _segments = {};
  List<Intersection> _intersections = [];
  List<RouteEdge> _edges = [];
  bool _initialized = false;

  static const double _intersectionThreshold = 50.0;

  // ── INICIALIZACIÓN ──────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    final csv = await rootBundle.loadString(
      'assets/data/detections_categorized.csv',
    );
    _parseAndBuildGraph(csv);
    _initialized = true;
  }

  void _parseAndBuildGraph(String csvContent) {
    final lines = csvContent.split('\n');
    if (lines.isEmpty) return;

    final headers = lines[0].split(',');
    final latIdx = headers.indexOf('lat');
    final lonIdx = headers.indexOf('lon');
    final scoreIdx = headers.indexOf('score_final');
    final clusterIdx = headers.indexOf('cluster');

    if (latIdx < 0 || lonIdx < 0 || scoreIdx < 0 || clusterIdx < 0) return;

    final Map<int, List<Map<String, double>>> clusterPoints = {};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');
      final maxIdx =
          max(max(latIdx, lonIdx), max(scoreIdx, clusterIdx));
      if (cols.length <= maxIdx) continue;

      try {
        final lat = double.parse(cols[latIdx]);
        final lon = double.parse(cols[lonIdx]);
        final score = double.parse(cols[scoreIdx]);
        final cluster = int.parse(cols[clusterIdx]);

        clusterPoints.putIfAbsent(cluster, () => []);
        clusterPoints[cluster]!.add({'lat': lat, 'lon': lon, 'score': score});
      } catch (_) {
        continue;
      }
    }

    _segments = {};
    for (final entry in clusterPoints.entries) {
      final clusterId = entry.key;
      final points = entry.value;
      if (points.isEmpty) continue;

      final avgScore =
          points.map((p) => p['score']!).reduce((a, b) => a + b) /
              points.length;
      final avgLat =
          points.map((p) => p['lat']!).reduce((a, b) => a + b) / points.length;
      final avgLon =
          points.map((p) => p['lon']!).reduce((a, b) => a + b) / points.length;

      _segments[clusterId] = RoadSegment(
        clusterId: clusterId,
        avgScore: avgScore,
        centroid: LatLng(avgLat, avgLon),
        points: points.map((p) => LatLng(p['lat']!, p['lon']!)).toList(),
      );
    }

    _findIntersections();
  }

  void _findIntersections() {
    _intersections = [];
    _edges = [];

    final clusterList = _segments.values.toList();

    for (int i = 0; i < clusterList.length; i++) {
      for (int j = i + 1; j < clusterList.length; j++) {
        final segA = clusterList[i];
        final segB = clusterList[j];

        double minDist = double.infinity;
        LatLng? closestA, closestB;

        for (final pA in segA.points) {
          for (final pB in segB.points) {
            final dist = _distanceMeters(pA, pB);
            if (dist < minDist) {
              minDist = dist;
              closestA = pA;
              closestB = pB;
            }
          }
        }

        if (minDist <= _intersectionThreshold &&
            closestA != null &&
            closestB != null) {
          final intersectionPoint = LatLng(
            (closestA.latitude + closestB.latitude) / 2,
            (closestA.longitude + closestB.longitude) / 2,
          );
          final intersectionId = _latLonId(intersectionPoint);

          if (!_intersections.any((inter) => inter.id == intersectionId)) {
            _intersections.add(Intersection(
              id: intersectionId,
              position: intersectionPoint,
              clusterIds: [segA.clusterId, segB.clusterId],
            ));
          }

          final distA = _distanceMeters(segA.centroid, intersectionPoint);
          final distB = _distanceMeters(segB.centroid, intersectionPoint);
          final centroidAId = _latLonId(segA.centroid);
          final centroidBId = _latLonId(segB.centroid);

          _edges.addAll([
            RouteEdge(
              fromId: centroidAId,
              toId: intersectionId,
              clusterId: segA.clusterId,
              score: segA.avgScore,
              distanceMeters: distA,
              pathPoints: [segA.centroid, intersectionPoint],
            ),
            RouteEdge(
              fromId: intersectionId,
              toId: centroidAId,
              clusterId: segA.clusterId,
              score: segA.avgScore,
              distanceMeters: distA,
              pathPoints: [intersectionPoint, segA.centroid],
            ),
            RouteEdge(
              fromId: centroidBId,
              toId: intersectionId,
              clusterId: segB.clusterId,
              score: segB.avgScore,
              distanceMeters: distB,
              pathPoints: [segB.centroid, intersectionPoint],
            ),
            RouteEdge(
              fromId: intersectionId,
              toId: centroidBId,
              clusterId: segB.clusterId,
              score: segB.avgScore,
              distanceMeters: distB,
              pathPoints: [intersectionPoint, segB.centroid],
            ),
          ]);
        }
      }
    }
  }

  // ── RUTEO CON DIJKSTRA ─────────────────────────────────────────

  RouteResult findRoute({
    required LatLng origin,
    required LatLng destination,
    required double minScore,
  }) {
    if (!_initialized || _segments.isEmpty) return RouteResult.notFound();

    final originNodeId = _nearestNodeId(origin);
    final destNodeId = _nearestNodeId(destination);

    if (originNodeId == null || destNodeId == null) {
      return RouteResult.notFound();
    }
    if (originNodeId == destNodeId) return RouteResult.notFound();

    final validEdges = _edges.where((e) => e.score >= minScore).toList();

    final Map<String, List<RouteEdge>> adjacency = {};
    for (final edge in validEdges) {
      adjacency.putIfAbsent(edge.fromId, () => []).add(edge);
    }

    final allNodes = <String>{};
    for (final edge in validEdges) {
      allNodes.add(edge.fromId);
      allNodes.add(edge.toId);
    }

    final Map<String, double> dist = {};
    final Map<String, String?> prev = {};
    final Map<String, RouteEdge?> prevEdge = {};
    final Set<String> visited = {};

    for (final node in allNodes) {
      dist[node] = double.infinity;
      prev[node] = null;
      prevEdge[node] = null;
    }
    dist[originNodeId] = 0;

    while (true) {
      String? u;
      double minDist = double.infinity;
      for (final node in allNodes) {
        final d = dist[node] ?? double.infinity;
        if (!visited.contains(node) && d < minDist) {
          minDist = d;
          u = node;
        }
      }
      if (u == null || u == destNodeId) break;
      visited.add(u);

      for (final edge in (adjacency[u] ?? [])) {
        final v = edge.toId;
        if (visited.contains(v)) continue;
        final weight = edge.distanceMeters / edge.score;
        final newDist = dist[u]! + weight;
        if (newDist < (dist[v] ?? double.infinity)) {
          dist[v] = newDist;
          prev[v] = u;
          prevEdge[v] = edge;
        }
      }
    }

    if ((dist[destNodeId] ?? double.infinity) == double.infinity) {
      return RouteResult.notFound();
    }

    final List<LatLng> polylinePoints = [origin];
    final List<double> segmentScores = [];
    double totalDistance = 0;
    String? current = destNodeId;

    final List<List<LatLng>> pathSegments = [];
    while (current != null && current != originNodeId) {
      final edge = prevEdge[current];
      if (edge == null) break;
      pathSegments.add(edge.pathPoints);
      segmentScores.add(edge.score);
      totalDistance += edge.distanceMeters;
      current = prev[current];
    }

    for (final segment in pathSegments.reversed) {
      polylinePoints.addAll(segment);
    }
    polylinePoints.add(destination);

    final avgScore = segmentScores.isEmpty
        ? 0.0
        : segmentScores.reduce((a, b) => a + b) / segmentScores.length;

    return RouteResult(
      polylinePoints: polylinePoints,
      totalDistance: totalDistance,
      avgAccessibility: avgScore,
      found: true,
      segmentsCount: segmentScores.length,
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────

  String? _nearestNodeId(LatLng point) {
    String? nearest;
    double minDist = double.infinity;

    for (final seg in _segments.values) {
      final d = _distanceMeters(point, seg.centroid);
      if (d < minDist) {
        minDist = d;
        nearest = _latLonId(seg.centroid);
      }
    }
    for (final inter in _intersections) {
      final d = _distanceMeters(point, inter.position);
      if (d < minDist) {
        minDist = d;
        nearest = inter.id;
      }
    }
    return nearest;
  }

  String _latLonId(LatLng point) {
    final lat = (point.latitude * 10000).round() / 10000;
    final lon = (point.longitude * 10000).round() / 10000;
    return '${lat}_$lon';
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLon * sinDLon;
    return 2 * earthRadius * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  // Getters para debug/visualización
  int get segmentCount => _segments.length;
  int get intersectionCount => _intersections.length;

  Set<Marker> get intersectionMarkers => _intersections
      .map(
        (inter) => Marker(
          markerId: MarkerId('inter_${inter.id}'),
          position: inter.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan,
          ),
          infoWindow: InfoWindow(
            title: 'Intersección',
            snippet: 'Clusters: ${inter.clusterIds.join(", ")}',
          ),
        ),
      )
      .toSet();
}
