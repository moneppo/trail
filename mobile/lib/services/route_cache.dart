import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

/// Stores snapped routes on the device so each walk is only sent to the map
/// matching service once. The key includes the point count and a version so
/// a changed track or a matcher update invalidates the entry.
class RouteCache {
  static const _version = 2;

  Future<File> _file(String walkId, int pointCount) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/snapped_routes');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return File('${cacheDir.path}/${walkId}_${pointCount}_v$_version.json');
  }

  Future<List<LatLng>?> read(String walkId, int pointCount) async {
    try {
      final file = await _file(walkId, pointCount);
      if (!await file.exists()) return null;
      final flat = (jsonDecode(await file.readAsString()) as List).cast<num>();
      if (flat.length != pointCount * 2) return null;
      return [
        for (var i = 0; i < flat.length; i += 2)
          LatLng(flat[i].toDouble(), flat[i + 1].toDouble()),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String walkId, List<LatLng> route) async {
    try {
      final file = await _file(walkId, route.length);
      await file.writeAsString(jsonEncode([
        for (final p in route) ...[p.latitude, p.longitude],
      ]));
    } catch (_) {
      // Caching is best-effort; a failed write just means re-matching later.
    }
  }
}
