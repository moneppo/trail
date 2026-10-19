import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/walk.dart';

class TrackedWalk {
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final List<WalkPoint> points;

  TrackedWalk({
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.points,
  });

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;
}

/// Records a single walk: buffers GPS samples in memory and only hands off
/// the full route once the walk is stopped, so a flaky connection mid-walk
/// never loses data.
class WalkTracker {
  StreamSubscription<Position>? _positionSub;
  Timer? _durationTimer;
  final List<Position> _positions = [];
  DateTime? _startedAt;
  double _distanceMeters = 0;

  final ValueNotifier<double> distance = ValueNotifier(0);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  bool get isTracking => _positionSub != null;

  /// iOS requires requesting "When In Use" before it will offer the
  /// "Always" upgrade prompt that Info.plist's
  /// NSLocationAlwaysAndWhenInUseUsageDescription enables.
  Future<bool> ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void start() {
    _positions.clear();
    _distanceMeters = 0;
    _startedAt = DateTime.now();
    distance.value = 0;
    duration.value = Duration.zero;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 8,
    );
    _positionSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt != null) {
        duration.value = DateTime.now().difference(startedAt);
      }
    });
  }

  void _onPosition(Position position) {
    if (_positions.isNotEmpty) {
      final last = _positions.last;
      _distanceMeters += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      distance.value = _distanceMeters;
    }
    _positions.add(position);
  }

  Future<TrackedWalk?> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    final startedAt = _startedAt;
    if (startedAt == null || _positions.isEmpty) return null;

    final endedAt = DateTime.now();
    final points = <WalkPoint>[
      for (var i = 0; i < _positions.length; i++)
        WalkPoint(
          lat: _positions[i].latitude,
          lng: _positions[i].longitude,
          altitude: _positions[i].altitude,
          recordedAt: _positions[i].timestamp,
          sequence: i,
        ),
    ];

    return TrackedWalk(
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: _distanceMeters,
      points: points,
    );
  }
}
