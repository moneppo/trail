import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/walk.dart';
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

  Future<List<WalkPoint>> fetchWalkPoints(String walkId) async {
    final rows = await _client
        .from('walk_points')
        .select()
        .eq('walk_id', walkId)
        .order('sequence', ascending: true);
    return (rows as List)
        .map((r) => WalkPoint.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
