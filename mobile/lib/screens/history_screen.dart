import 'package:flutter/material.dart';

import '../models/walk.dart';
import '../services/supabase_service.dart';
import '../theme/trail_theme.dart';
import '../widgets/trail_widgets.dart';
import 'walk_detail_screen.dart';

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
    final c = TrailColors.of(context);
    return Scaffold(
      body: SafeArea(
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: c.ink, width: strokeBold)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SquareGlyphButton(
                        glyph: '‹',
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 12),
                      LabelText(summary.isEmpty ? ' ' : summary),
                      Text('Your walks', style: TrailText.titleXl(c)),
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
                Expanded(child: _body(context, c, snapshot, walks)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, TrailColors c,
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
        child: Text('No walks yet. Go for one.', style: TrailText.caption(c)),
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
