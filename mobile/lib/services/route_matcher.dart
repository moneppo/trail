import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// What happened when a route was matched, for showing in the UI and logs.
class MatchSummary {
  int total = 0;
  int snapped = 0; // moved onto a street/sidewalk/trail
  int kept = 0; // Valhalla matched them but they were already on the line
  int unmatched = 0; // Valhalla found nothing nearby: raw GPS kept
  int rejected = 0; // snap would move the point > maxSnapMeters: raw GPS kept
  int chunks = 0;
  final List<String> problems = [];
  bool fromCache = false;

  /// True when matching ran to completion and actually moved something.
  bool get usable => problems.isEmpty && snapped > 0;

  @override
  String toString() {
    if (fromCache) return 'Snapped route loaded from cache';
    final parts = [
      '$snapped of $total points snapped',
      if (unmatched > 0) '$unmatched had no street/trail nearby',
      if (rejected > 0) '$rejected too far to snap',
      if (problems.isNotEmpty) 'problems: ${problems.join('; ')}',
    ];
    return parts.join(', ');
  }
}

/// Snaps a recorded GPS track to known streets, sidewalks and trails using
/// Valhalla's map matching (OpenStreetMap data, pedestrian costing).
///
/// Anything Valhalla can't match, or that would move a point further than
/// [maxSnapMeters] from where we actually measured it, keeps its raw GPS
/// position. On any network or API failure the raw track is returned.
class RouteMatcher {
  // Public FOSSGIS instance: fine for prototyping, but has fair-use limits.
  // Point this at a self-hosted Valhalla for heavier use.
  static final _endpoint =
      Uri.parse('https://valhalla1.openstreetmap.de/trace_attributes');

  static const _chunkSize = 400;
  static const _overlap = 10;
  static const maxSnapMeters = 25.0;

  final http.Client _client;
  final _distance = const Distance();

  RouteMatcher({http.Client? client}) : _client = client ?? http.Client();

  static void _log(String message) => debugPrint('[RouteMatcher] $message');

  Future<({List<LatLng> route, MatchSummary summary})> match(
      List<LatLng> raw) async {
    final summary = MatchSummary()..total = raw.length;
    if (raw.length < 2) return (route: raw, summary: summary);

    _log('matching ${raw.length} points');
    final result = List<LatLng>.of(raw);
    for (var start = 0; start < raw.length - 1; start += _chunkSize) {
      final end = (start + _chunkSize + _overlap).clamp(0, raw.length);
      summary.chunks++;
      try {
        final snapped = await _matchChunk(raw.sublist(start, end), summary);
        if (snapped == null) continue;
        // Each chunk carries a few extra trailing points so matching has
        // context at the seam; only the chunk's own points are kept.
        final take =
            start + _chunkSize < raw.length ? _chunkSize : snapped.length;
        for (var i = 0; i < take && i < snapped.length; i++) {
          result[start + i] = snapped[i];
        }
      } catch (e) {
        summary.problems.add('chunk ${summary.chunks}: $e');
        _log('chunk ${summary.chunks} failed: $e');
      }
    }

    summary.snapped = 0;
    for (var i = 0; i < raw.length; i++) {
      if (result[i] != raw[i]) summary.snapped++;
    }
    _log(summary.toString());
    return (route: result, summary: summary);
  }

  Future<List<LatLng>?> _matchChunk(
      List<LatLng> chunk, MatchSummary summary) async {
    final response = await _client
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Trail/1.0 (com.moneppo.trail)',
          },
          body: jsonEncode({
            'shape': [
              for (final p in chunk) {'lat': p.latitude, 'lon': p.longitude},
            ],
            'costing': 'pedestrian',
            'shape_match': 'map_snap',
            'trace_options': {'search_radius': maxSnapMeters, 'gps_accuracy': 10},
            'filters': {
              'attributes': ['matched.point', 'matched.type'],
              'action': 'include',
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    _log('chunk ${summary.chunks} (${chunk.length} pts): HTTP ${response.statusCode}');

    // 400/442 mean Valhalla found nothing to snap this chunk to: keep raw.
    if (response.statusCode == 400 || response.statusCode == 442) {
      final body = response.body.length > 160
          ? response.body.substring(0, 160)
          : response.body;
      summary.problems.add('chunk ${summary.chunks}: no match (HTTP ${response.statusCode}) $body');
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException('Valhalla returned ${response.statusCode}');
    }

    final matched =
        (jsonDecode(response.body)['matched_points'] as List?) ?? const [];
    if (matched.length != chunk.length) {
      summary.problems.add(
          'chunk ${summary.chunks}: got ${matched.length} matched points for ${chunk.length}');
      return null;
    }

    return [
      for (var i = 0; i < chunk.length; i++)
        _pick(chunk[i], matched[i] as Map<String, dynamic>, summary),
    ];
  }

  LatLng _pick(LatLng raw, Map<String, dynamic> m, MatchSummary summary) {
    if (m['type'] == 'unmatched') {
      summary.unmatched++;
      return raw;
    }
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      summary.unmatched++;
      return raw;
    }
    final snapped = LatLng(lat, lon);
    if (_distance(raw, snapped) > maxSnapMeters) {
      summary.rejected++;
      return raw;
    }
    return snapped;
  }
}
