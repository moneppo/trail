import 'package:flutter/material.dart';

import '../models/walk.dart';
import '../services/supabase_service.dart';
import '../theme/theme_controller.dart';
import '../theme/trail_theme.dart';
import '../widgets/options_sheet.dart';
import '../widgets/trail_widgets.dart';
import 'record_screen.dart';
import 'walk_detail_screen.dart';

/// Your walks, with a button to start a new one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = SupabaseService();
  late Future<List<Walk>> _walksFuture;

  @override
  void initState() {
    super.initState();
    _walksFuture = _service.fetchWalks();
  }

  Future<void> _newWalk() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecordScreen()),
    );
    if (!mounted) return;
    // A walk may have been saved, so read the list again.
    setState(() => _walksFuture = _service.fetchWalks());
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
    final c = TrailColors.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Walk>>(
          future: _walksFuture,
          builder: (context, snapshot) {
            final walks = snapshot.data;
            final summary = walks == null
                ? ''
                : '${walks.length} ${walks.length == 1 ? 'walk' : 'walks'} · '
                    '${(walks.fold<double>(0, (sum, w) => sum + w.distanceMeters) / 1000).toStringAsFixed(1)} km';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: c.inkSoft, width: strokeLine)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TrailLink(
                            text: 'Options',
                            onPressed: () =>
                                showOptionsSheet(context, themeController),
                          ),
                          const SizedBox(width: 20),
                          TrailLink(
                            text: 'Sign out',
                            onPressed: () => _service.signOut(),
                          ),
                        ],
                      ),
                      LabelText(summary.isEmpty ? ' ' : summary),
                      Text('Your walks', style: TrailText.titleXl(c)),
                    ],
                  ),
                ),
                Expanded(child: _list(context, c, snapshot, walks)),
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: c.paper,
                    border: Border(
                        top: BorderSide(color: c.inkSoft, width: strokeLine)),
                  ),
                  child: TrailButton(
                    primary: true,
                    label: 'New walk',
                    onPressed: _newWalk,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, TrailColors c,
      AsyncSnapshot<List<Walk>> snapshot, List<Walk>? walks) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load walks: ${snapshot.error}',
            style: TrailText.error(c)),
      );
    }
    if (walks == null || walks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No walks yet. Tap New walk to record your first.',
            style: TrailText.caption(c)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: walks.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: strokeHair, color: c.rule),
      itemBuilder: (context, index) {
        final walk = walks[index];
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WalkDetailScreen(walk: walk)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabelText('${walk.startedAt.toLocal()}'.split('.').first),
                      Text(
                        '${(walk.distanceMeters / 1000).toStringAsFixed(2)} km',
                        style: TrailText.titleMd(c),
                      ),
                    ],
                  ),
                ),
                Text(_formatDuration(walk.durationSeconds),
                    style: TrailText.data(c)),
              ],
            ),
          ),
        );
      },
    );
  }
}
