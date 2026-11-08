import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
  StreamSubscription<Position>? _previewSub;
  Timer? _durationTimer;
  final List<Position> _positions = [];
  DateTime? _startedAt;
  double _distanceMeters = 0;

  final ValueNotifier<double> distance = ValueNotifier(0);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  /// The latest known position, before and during a walk.
  final ValueNotifier<LatLng?> current = ValueNotifier(null);

  /// How many points the walk has recorded so far.
  final ValueNotifier<int> pointCount = ValueNotifier(0);

  bool get isTracking => _positionSub != null;

  /// The recorded route so far.
  List<LatLng> get track =>
      [for (final p in _positions) LatLng(p.latitude, p.longitude)];

  /// Follows the device's position without recording, so the map can show
  /// where the walker is before the walk starts.
  Future<void> startPreview() async {
    if (_previewSub != null || isTracking) return;
    final last = await Geolocator.getLastKnownPosition();
    if (last != null && current.value == null) {
      current.value = LatLng(last.latitude, last.longitude);
    }
    _previewSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((p) => current.value = LatLng(p.latitude, p.longitude));
  }

  Future<void> _stopPreview() async {
    await _previewSub?.cancel();
    _previewSub = null;
  }

  /// Releases the location streams and notifiers. Call when the screen goes away.
  void dispose() {
    _previewSub?.cancel();
    _positionSub?.cancel();
    _durationTimer?.cancel();
    distance.dispose();
    duration.dispose();
    current.dispose();
    pointCount.dispose();
  }

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

  Future<void> start() async {
    await _stopPreview();
    _positions.clear();
    _distanceMeters = 0;
    pointCount.value = 0;
    _startedAt = DateTime.now();
    distance.value = 0;
    duration.value = Duration.zero;

    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3,
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
    current.value = LatLng(position.latitude, position.longitude);
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
    pointCount.value = _positions.length;
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
