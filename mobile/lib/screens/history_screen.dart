import 'package:flutter/material.dart';

import '../models/walk.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = SupabaseService();
  late Future<List<Walk>> _walksFuture;

  @override
  void initState() {
    super.initState();
    _walksFuture = _service.fetchWalks();
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Walks')),
      body: FutureBuilder<List<Walk>>(
        future: _walksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final walks = snapshot.data ?? [];
          if (walks.isEmpty) {
            return const Center(child: Text('No walks yet. Go for one!'));
          }
          return ListView.separated(
            itemCount: walks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final walk = walks[index];
              return ListTile(
                title: Text('${(walk.distanceMeters / 1000).toStringAsFixed(2)} km'),
                subtitle: Text(
                  '${walk.startedAt.toLocal()}'.split('.').first,
                ),
                trailing: Text(_formatDuration(walk.durationSeconds)),
              );
            },
          );
        },
      ),
    );
  }
}
