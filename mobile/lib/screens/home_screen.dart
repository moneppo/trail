import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/walk_tracker.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tracker = WalkTracker();
  final _service = SupabaseService();
  bool _uploading = false;
  String? _error;

  Future<void> _onStartPressed() async {
    setState(() => _error = null);
    final granted = await _tracker.ensurePermissions();
    if (!granted) {
      setState(() => _error = 'Location permission is required to track a walk.');
      return;
    }
    setState(() => _tracker.start());
  }

  Future<void> _onStopPressed() async {
    final walk = await _tracker.stop();
    setState(() {});
    if (walk == null) return;

    setState(() => _uploading = true);
    try {
      await _service.uploadWalk(walk);
    } catch (e) {
      setState(() => _error = 'Could not upload walk: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _service.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _tracker.duration,
              builder: (_, duration, _) => Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: _tracker.distance,
              builder: (_, meters, _) => Text(
                '${(meters / 1000).toStringAsFixed(2)} km',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_uploading) const CircularProgressIndicator(),
            if (!_uploading)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _tracker.isTracking ? Colors.red : null,
                  minimumSize: const Size(160, 56),
                ),
                onPressed: _tracker.isTracking ? _onStopPressed : _onStartPressed,
                child: Text(_tracker.isTracking ? 'Stop Walk' : 'Start Walk'),
              ),
          ],
        ),
      ),
    );
  }
}
