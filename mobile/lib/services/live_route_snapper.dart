import 'package:latlong2/latlong.dart';

import 'route_matcher.dart';

/// The route as it should be drawn right now: snapped where a match exists,
/// raw for the newest points that haven't been matched yet.
class LiveRoute {
  final List<LatLng> route;
  final List<MatchStatus> statuses;
  const LiveRoute(this.route, this.statuses);
}

/// Snaps a walk to streets and trails while it is still being recorded,
/// without sending the whole route to the matching server each time.
///
/// Each [update] matches only the points that are new or still unsettled,
/// plus a few earlier ones for context. The newest points stay open for a
/// while ([_tail]) because a match can shift when more of the route is known;
/// everything older is final and is never sent again.
class LiveRouteSnapper {
  static const _tail = 8;
  static const _overlap = 10;
  static const _minNew = 4;

  final RouteMatcher _matcher;
  final List<LatLng> _snapped = [];
  final List<MatchStatus> _statuses = [];
  // Points before this index are final.
  int _stable = 0;
  bool _busy = false;

  LiveRouteSnapper({RouteMatcher? matcher}) : _matcher = matcher ?? RouteMatcher();

  /// Matches the recent part of [raw]. Does nothing while a match is already
  /// running or when there's too little new to be worth a request. A failed
  /// match leaves things as they were and is simply tried again next time.
  Future<void> update(List<LatLng> raw) async {
    if (_busy) return;
    if (raw.length - _snapped.length < _minNew && _snapped.isNotEmpty) return;
    if (raw.length < 2) return;
    _busy = true;
    try {
      final start = _stable > _overlap ? _stable - _overlap : 0;
      final window = raw.sublist(start);
      final result = await _matcher.match(window);
      if (!result.complete) return;

      for (var i = 0; i < window.length; i++) {
        final index = start + i;
        // Settled points are never overwritten; the overlap is only context.
        if (index < _stable) continue;
        if (index < _snapped.length) {
          _snapped[index] = result.route[i];
          _statuses[index] = result.statuses[i];
        } else {
          _snapped.add(result.route[i]);
          _statuses.add(result.statuses[i]);
        }
      }
      final settled = raw.length - _tail;
      if (settled > _stable) _stable = settled;
    } finally {
      _busy = false;
    }
  }

  /// [raw] with the matched part replaced by its snapped version. Points that
  /// haven't been matched yet are shown as recorded and treated as on-map so
  /// they don't flash as unmapped before they are matched.
  LiveRoute build(List<LatLng> raw) {
    final route = <LatLng>[];
    final statuses = <MatchStatus>[];
    for (var i = 0; i < raw.length; i++) {
      if (i < _snapped.length) {
        route.add(_snapped[i]);
        statuses.add(_statuses[i]);
      } else {
        route.add(raw[i]);
        statuses.add(MatchStatus.matched);
      }
    }
    return LiveRoute(route, statuses);
  }
}
