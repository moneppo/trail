import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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

  /// Returns the snapped route and whether matching ran to completion.
  /// An incomplete result (network error, rate limit, server error) is the
  /// raw route and should not be cached; a complete one may still contain raw
  /// points wherever Valhalla found nothing to snap to.
  Future<({List<LatLng> route, bool complete})> match(List<LatLng> raw) async {
    if (raw.length < 2) return (route: raw, complete: true);
    final result = List<LatLng>.of(raw);
    try {
      for (var start = 0; start < raw.length - 1; start += _chunkSize) {
        final end = (start + _chunkSize + _overlap).clamp(0, raw.length);
        final snapped = await _matchChunk(raw.sublist(start, end));
        if (snapped == null) continue;
        // Each chunk carries a few extra trailing points so matching has
        // context at the seam; only the chunk's own points are kept.
        final take = start + _chunkSize < raw.length
            ? _chunkSize
            : snapped.length;
        for (var i = 0; i < take && i < snapped.length; i++) {
          result[start + i] = snapped[i];
        }
      }
    } catch (_) {
      return (route: raw, complete: false);
    }
    return (route: result, complete: true);
  }

  Future<List<LatLng>?> _matchChunk(List<LatLng> chunk) async {
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
    // 400/442 mean Valhalla found nothing to snap this chunk to: keep the raw
    // points. Anything else (429, 5xx) is transient, so abort and don't cache.
    if (response.statusCode == 400 || response.statusCode == 442) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('Valhalla returned ${response.statusCode}');
    }

    final matched =
        (jsonDecode(response.body)['matched_points'] as List?) ?? const [];
    if (matched.length != chunk.length) return null;

    return [
      for (var i = 0; i < chunk.length; i++)
        _pick(chunk[i], matched[i] as Map<String, dynamic>),
    ];
  }

  LatLng _pick(LatLng raw, Map<String, dynamic> m) {
    if (m['type'] == 'unmatched') return raw;
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return raw;
    final snapped = LatLng(lat, lon);
    return _distance(raw, snapped) > maxSnapMeters ? raw : snapped;
  }
}
