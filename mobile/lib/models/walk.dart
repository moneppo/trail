class Walk {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int durationSeconds;

  Walk({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory Walk.fromJson(Map<String, dynamic> json) {
    return Walk(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
    );
  }
}

class WalkPoint {
  final double lat;
  final double lng;
  final double? altitude;
  final DateTime recordedAt;
  final int sequence;

  WalkPoint({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    required this.sequence,
    this.altitude,
  });

  factory WalkPoint.fromJson(Map<String, dynamic> json) {
    return WalkPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      sequence: json['sequence'] as int,
    );
  }

  Map<String, dynamic> toInsertJson(String walkId) {
    return {
      'walk_id': walkId,
      'lat': lat,
      'lng': lng,
      'altitude': altitude,
      'recorded_at': recordedAt.toIso8601String(),
      'sequence': sequence,
    };
  }
}

/// A stretch of a walk (inclusive point indices) submitted as an untracked
/// trail. Candidates await review; accepted ones are on the map.
class SubmittedTrail {
  final int start;
  final int end;
  final bool accepted;

  const SubmittedTrail(this.start, this.end, {this.accepted = false});
}
