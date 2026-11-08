import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/walk_tracker.dart';
import '../theme/theme_controller.dart';
import '../theme/trail_theme.dart';
import '../widgets/options_sheet.dart';
import '../widgets/trail_widgets.dart';
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
    final c = TrailColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: c.inkSoft, width: strokeLine)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Trail', style: TrailText.titleLg(c))),
                  TrailLink(
                    text: 'Walks',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TrailLink(
                    text: 'Options',
                    onPressed: () => showOptionsSheet(context, themeController),
                  ),
                  const SizedBox(width: 20),
                  TrailLink(
                    text: 'Sign out',
                    onPressed: () => _service.signOut(),
                  ),
                ],
              ),
            ),
            Container(
              height: 4,
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: c.ink, width: strokeHair)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LabelText('Elapsed')),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<Duration>(
                      valueListenable: _tracker.duration,
                      builder: (_, duration, _) => Text(
                        _formatDuration(duration),
                        textAlign: TextAlign.center,
                        style: TrailText.data(c).copyWith(
                          fontSize: 64,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(child: LabelText('Distance')),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<double>(
                      valueListenable: _tracker.distance,
                      builder: (_, meters, _) => Text(
                        '${(meters / 1000).toStringAsFixed(2)} km',
                        textAlign: TextAlign.center,
                        style: TrailText.data(c).copyWith(
                            fontSize: 28, height: 1.2, letterSpacing: 1.12),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!,
                            style: TrailText.error(c),
                            textAlign: TextAlign.center),
                      ),
                    if (_uploading)
                      Center(child: Text('Saving walk…', style: TrailText.caption(c)))
                    else
                      TrailButton(
                        primary: true,
                        label: _tracker.isTracking ? 'Stop walk' : 'Start walk',
                        onPressed:
                            _tracker.isTracking ? _onStopPressed : _onStartPressed,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
