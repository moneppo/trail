import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trail/services/live_route_snapper.dart';
import 'package:trail/services/route_matcher.dart';

/// A matcher whose server "snaps" every point 0.001 degrees east and records
/// how many points each request carried.
({RouteMatcher matcher, List<int> sizes}) _fakeMatcher({bool fail = false}) {
  final sizes = <int>[];
  final client = MockClient((request) async {
    if (fail) return http.Response('busy', 503);
    final shape = (jsonDecode(request.body)['shape'] as List);
    sizes.add(shape.length);
    return http.Response(
      jsonEncode({
        'matched_points': [
          for (final p in shape)
            {'lat': p['lat'], 'lon': (p['lon'] as num) + 0.0001, 'type': 'matched'},
        ],
      }),
      200,
    );
  });
  return (matcher: RouteMatcher(client: client), sizes: sizes);
}

List<LatLng> _walk(int n) =>
    [for (var i = 0; i < n; i++) LatLng(51.0 + i * 0.00003, -1.0)];

void main() {
  test('shows recorded points as they are until a match arrives', () {
    final fake = _fakeMatcher();
    final snapper = LiveRouteSnapper(matcher: fake.matcher);
    final raw = _walk(5);
    final live = snapper.build(raw);
    expect(live.route, raw);
    expect(live.statuses.every((s) => s == MatchStatus.matched), isTrue);
  });

  test('snaps the walk so far, then only sends the unsettled part', () async {
    final fake = _fakeMatcher();
    final snapper = LiveRouteSnapper(matcher: fake.matcher);

    final first = _walk(30);
    await snapper.update(first);
    expect(fake.sizes, [30]);
    var live = snapper.build(first);
    expect(live.route.first.longitude, closeTo(-0.9999, 1e-9));

    // 12 more points arrive. Points up to index 22 are settled, so the next
    // request starts a little before that (10 points of context) instead of
    // resending the whole walk.
    final second = _walk(42);
    await snapper.update(second);
    expect(fake.sizes.last, 42 - 12);
    live = snapper.build(second);
    expect(live.route.length, 42);
    expect(live.route.every((p) => p.longitude > -1.0), isTrue);
  });

  test('skips the request when little has changed', () async {
    final fake = _fakeMatcher();
    final snapper = LiveRouteSnapper(matcher: fake.matcher);
    await snapper.update(_walk(30));
    await snapper.update(_walk(32));
    expect(fake.sizes.length, 1);
  });

  test('a failed match changes nothing and is retried later', () async {
    final failing = _fakeMatcher(fail: true);
    final snapper = LiveRouteSnapper(matcher: failing.matcher);
    final raw = _walk(30);
    await snapper.update(raw);
    expect(snapper.build(raw).route, raw);
  });
}
