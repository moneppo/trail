import 'package:flutter/material.dart';

import '../models/walk.dart';
import '../services/supabase_service.dart';
import '../theme/settings_controller.dart';
import '../theme/trail_theme.dart';
import '../utils/format.dart';
import '../widgets/options_sheet.dart';
import '../widgets/trail_icons.dart';
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
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const RecordScreen()));
    if (!mounted) return;
    // A walk may have been saved, so read the list again.
    setState(() => _walksFuture = _service.fetchWalks());
  }

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    // Rebuild when the distance unit changes.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<Walk>>(
            future: _walksFuture,
            builder: (context, snapshot) {
              final walks = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.inkSoft, width: strokeLine),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your walks',
                            style: TrailText.titleXl(c),
                          ),
                        ),
                        FloatingIconButton(
                          icon: TrailIcon.person,
                          semanticLabel: 'Options',
                          onPressed: () => showOptionsSheet(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _list(context, c, snapshot, walks)),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: c.paper,
                      border: Border(
                        top: BorderSide(color: c.inkSoft, width: strokeLine),
                      ),
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
      ),
    );
  }

  Widget _list(
    BuildContext context,
    TrailColors c,
    AsyncSnapshot<List<Walk>> snapshot,
    List<Walk>? walks,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load walks: ${snapshot.error}',
          style: TrailText.error(c),
        ),
      );
    }
    if (walks == null || walks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No walks yet. Tap New walk to record your first.',
          style: TrailText.caption(c),
        ),
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
                      Text(
                        friendlyDateTime(context, walk.startedAt),
                        style: TrailText.titleMd(c),
                      ),
                      Text(
                        formatDistance(walk.distanceMeters, settings.units),
                        style: TrailText.data(c).copyWith(color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatDuration(Duration(seconds: walk.durationSeconds)),
                  style: TrailText.data(c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
