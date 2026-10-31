import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/walk.dart';
import 'route_matcher.dart';
import 'walk_tracker.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> uploadWalk(TrackedWalk walk) async {
    final userId = currentUser!.id;
    final inserted = await _client
        .from('walks')
        .insert({
          'user_id': userId,
          'started_at': walk.startedAt.toIso8601String(),
          'ended_at': walk.endedAt.toIso8601String(),
          'distance_meters': walk.distanceMeters,
          'duration_seconds': walk.durationSeconds,
        })
        .select()
        .single();

    final walkId = inserted['id'] as String;
    if (walk.points.isNotEmpty) {
      await _client
          .from('walk_points')
          .insert(walk.points.map((p) => p.toInsertJson(walkId)).toList());
    }
  }

  Future<List<Walk>> fetchWalks() async {
    final rows = await _client
        .from('walks')
        .select()
        .order('started_at', ascending: false);
    return (rows as List).map((r) => Walk.fromJson(r as Map<String, dynamic>)).toList();
  }

  // PostgREST caps a single response (1000 rows by default), and a walk
  // recorded every few meters easily exceeds that, so read in pages.
  static const _pageSize = 1000;

  Future<List<Map<String, dynamic>>> _fetchAllByWalk(
      String table, String walkId) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final page = await _client
          .from(table)
          .select()
          .eq('walk_id', walkId)
          .order('sequence', ascending: true)
          .range(from, from + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
    }
    return rows;
  }

  Future<List<WalkPoint>> fetchWalkPoints(String walkId) async {
    final rows = await _fetchAllByWalk('walk_points', walkId);
    return rows.map(WalkPoint.fromJson).toList();
  }

  /// The stored snapped route for a walk, or null if none is saved.
  Future<MatchResult?> fetchSnappedRoute(String walkId) async {
    final rows = await _fetchAllByWalk('snapped_points', walkId);
    if (rows.isEmpty) return null;
    return MatchResult(
      [
        for (final r in rows)
          LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
      ],
      [
        for (final r in rows)
          MatchStatus.values.byName(r['match_status'] as String),
      ],
      const [],
      const [],
    );
  }

  /// Stretches of a walk already submitted as untracked trails, as
  /// (start_sequence, end_sequence) pairs.
  Future<List<(int, int)>> fetchUntrackedTrails(String walkId) async {
    final rows = await _client
        .from('untracked_trails')
        .select('start_sequence, end_sequence')
        .eq('walk_id', walkId);
    return [
      for (final r in rows)
        (r['start_sequence'] as int, r['end_sequence'] as int),
    ];
  }

  /// Submits a stretch as a candidate untracked trail.
  Future<void> submitUntrackedTrail(String walkId, int start, int end) async {
    await _client.from('untracked_trails').insert({
      'user_id': currentUser!.id,
      'walk_id': walkId,
      'type': 'candidate',
      'start_sequence': start,
      'end_sequence': end,
    });
  }

  /// Stores a completed match. Upserts on (walk_id, sequence) so a partial
  /// earlier save is repaired rather than duplicated.
  Future<void> saveSnappedRoute(String walkId, MatchResult result) async {
    const batch = 500;
    for (var i = 0; i < result.route.length; i += batch) {
      final end = (i + batch).clamp(0, result.route.length);
      await _client.from('snapped_points').upsert([
        for (var j = i; j < end; j++)
          {
            'walk_id': walkId,
            'sequence': j,
            'lat': result.route[j].latitude,
            'lng': result.route[j].longitude,
            'match_status': result.statuses[j].name,
          },
      ], onConflict: 'walk_id,sequence');
    }
  }
}
