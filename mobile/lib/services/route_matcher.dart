import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// What the matcher did with one point. Stored as snapped_points.match_status.
enum MatchStatus {
  /// Snapped onto a known street, sidewalk or trail.
  matched,

  /// Nothing mapped nearby: the raw GPS position is kept.
  unmatched,

  /// The snap would have moved the point too far: the raw position is kept.
  rejected,
}

class MatchResult {
  final List<LatLng> route;
  final List<MatchStatus> statuses;

  /// Transient failures (network, rate limit, server error). When non-empty
  /// the result is only a best effort and must not be stored.
  final List<String> errors;

  /// Chunks Valhalla answered "no match" for; their points are `unmatched`.
  final List<String> notes;

  MatchResult(this.route, this.statuses, this.errors, this.notes);

  bool get complete => errors.isEmpty;
  int count(MatchStatus s) => statuses.where((x) => x == s).length;

  /// Human-readable summary for the UI and logs.
  String describe() {
    final parts = [
      '${count(MatchStatus.matched)} of ${route.length} points snapped',
      if (count(MatchStatus.unmatched) > 0)
        '${count(MatchStatus.unmatched)} had no street/trail nearby',
      if (count(MatchStatus.rejected) > 0)
        '${count(MatchStatus.rejected)} too far to snap',
      if (notes.isNotEmpty) notes.join('; '),
      if (errors.isNotEmpty) 'problems: ${errors.join('; ')}',
    ];
    return parts.join(', ');
  }
}

/// Snaps a recorded GPS track to known streets, sidewalks and trails using
/// Valhalla's map matching (OpenStreetMap data, pedestrian costing).
///
/// Anything Valhalla can't match, or that would move a point further than
/// [maxSnapMeters] from where we actually measured it, keeps its raw GPS
/// position and is marked accordingly in [MatchResult.statuses].
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

  Future<MatchResult> match(List<LatLng> raw) async {
    final route = List<LatLng>.of(raw);
    final statuses = List<MatchStatus>.filled(raw.length, MatchStatus.unmatched);
    final errors = <String>[];
    final notes = <String>[];
    if (raw.length < 2) return MatchResult(route, statuses, errors, notes);

    _log('matching ${raw.length} points');
    var index = 0;
    for (var start = 0; start < raw.length - 1; start += _chunkSize) {
      final end = (start + _chunkSize + _overlap).clamp(0, raw.length);
      index++;
      try {
        final chunk = await _matchChunk(raw.sublist(start, end), index, notes);
        if (chunk == null) continue;
        // Each chunk carries a few extra trailing points so matching has
        // context at the seam; only the chunk's own points are kept.
        final take =
            start + _chunkSize < raw.length ? _chunkSize : chunk.length;
        for (var i = 0; i < take && i < chunk.length; i++) {
          route[start + i] = chunk[i].$1;
          statuses[start + i] = chunk[i].$2;
        }
      } catch (e) {
        errors.add('chunk $index: $e');
        _log('chunk $index failed: $e');
      }
    }

    final result = MatchResult(route, statuses, errors, notes);
    _log(result.describe());
    return result;
  }

  Future<List<(LatLng, MatchStatus)>?> _matchChunk(
      List<LatLng> chunk, int index, List<String> notes) async {
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
    _log('chunk $index (${chunk.length} pts): HTTP ${response.statusCode}');

    // 400/442 mean Valhalla found nothing to snap this chunk to: all of its
    // points are unmatched. Anything else (429, 5xx) is a transient failure.
    if (response.statusCode == 400 || response.statusCode == 442) {
      notes.add('chunk $index: no match (HTTP ${response.statusCode})');
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException('Valhalla returned ${response.statusCode}');
    }

    final matched =
        (jsonDecode(response.body)['matched_points'] as List?) ?? const [];
    if (matched.length != chunk.length) {
      throw http.ClientException(
          'got ${matched.length} matched points for ${chunk.length}');
    }

    return [
      for (var i = 0; i < chunk.length; i++)
        _pick(chunk[i], matched[i] as Map<String, dynamic>),
    ];
  }

  (LatLng, MatchStatus) _pick(LatLng raw, Map<String, dynamic> m) {
    if (m['type'] == 'unmatched') return (raw, MatchStatus.unmatched);
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return (raw, MatchStatus.unmatched);
    final snapped = LatLng(lat, lon);
    if (_distance(raw, snapped) > maxSnapMeters) {
      return (raw, MatchStatus.rejected);
    }
    return (snapped, MatchStatus.matched);
  }
}
