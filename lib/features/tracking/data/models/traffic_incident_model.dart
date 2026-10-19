import 'package:latlong2/latlong.dart';

enum TrafficIncidentType {
  roadClosed,
  roadWorks,
  accident,
  jam,
  danger,
  other,
}

class TrafficIncident {
  final String id;
  final int iconCategory;
  final TrafficIncidentType type;
  final String description;
  final int delaySeconds;
  final LatLng point;
  final List<LatLng> polyline;
  final String? roadName;

  const TrafficIncident({
    required this.id,
    required this.iconCategory,
    required this.type,
    required this.description,
    required this.delaySeconds,
    required this.point,
    required this.polyline,
    this.roadName,
  });

  bool get isRoadClosed => iconCategory == 8 || type == TrafficIncidentType.roadClosed;
  bool get isRoadWorks => iconCategory == 9 || type == TrafficIncidentType.roadWorks;
  bool get isAccident => iconCategory == 1 || type == TrafficIncidentType.accident;
  bool get isJam => iconCategory == 6 || type == TrafficIncidentType.jam;

  String? get delayBadge {
    if (delaySeconds <= 0) return null;
    final int minutes = (delaySeconds / 60).round();
    return minutes > 0 ? "$minutes'" : null;
  }

  factory TrafficIncident.fromJson(Map<String, dynamic> json, int index) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};

    final int category = (properties['iconCategory'] as num?)?.toInt() ?? 0;
    final int delay = (properties['delay'] as num?)?.toInt() ?? 0;
    final String road = (properties['roadNumbers'] as List<dynamic>?)?.join(', ') ??
        (properties['from'] as String?) ??
        '';

    TrafficIncidentType mappedType = TrafficIncidentType.other;
    if (category == 8) {
      mappedType = TrafficIncidentType.roadClosed;
    } else if (category == 9) {
      mappedType = TrafficIncidentType.roadWorks;
    } else if (category == 1) {
      mappedType = TrafficIncidentType.accident;
    } else if (category == 6) {
      mappedType = TrafficIncidentType.jam;
    } else if (category == 3 || category == 2 || category == 10 || category == 11) {
      mappedType = TrafficIncidentType.danger;
    }

    final List<LatLng> coords = [];
    final geomType = geometry['type'] as String? ?? '';
    final rawCoords = geometry['coordinates'];

    if (geomType == 'LineString' && rawCoords is List) {
      for (final pt in rawCoords) {
        if (pt is List && pt.length >= 2) {
          final double lon = (pt[0] as num).toDouble();
          final double lat = (pt[1] as num).toDouble();
          coords.add(LatLng(lat, lon));
        }
      }
    } else if (geomType == 'Point' && rawCoords is List && rawCoords.length >= 2) {
      coords.add(LatLng((rawCoords[1] as num).toDouble(), (rawCoords[0] as num).toDouble()));
    }

    final LatLng mainPoint = coords.isNotEmpty ? coords.first : const LatLng(0, 0);

    String desc = '';
    if (mappedType == TrafficIncidentType.roadClosed) {
      desc = road.isNotEmpty ? 'Road Closed on $road' : 'Road Closed';
    } else if (mappedType == TrafficIncidentType.roadWorks) {
      desc = road.isNotEmpty ? 'Road Works on $road' : 'Road Works';
    } else if (mappedType == TrafficIncidentType.accident) {
      desc = road.isNotEmpty ? 'Accident reported on $road' : 'Accident Ahead';
    } else if (mappedType == TrafficIncidentType.jam) {
      final int min = (delay / 60).round();
      desc = min > 0 ? 'Heavy Traffic ($min min delay)' : 'Traffic Congestion';
    } else {
      desc = road.isNotEmpty ? 'Hazard on $road' : 'Traffic Hazard';
    }

    return TrafficIncident(
      id: properties['id']?.toString() ?? 'incident_$index',
      iconCategory: category,
      type: mappedType,
      description: desc,
      delaySeconds: delay,
      point: mainPoint,
      polyline: coords,
      roadName: road.isNotEmpty ? road : null,
    );
  }
}
