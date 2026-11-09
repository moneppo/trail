import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/settings_controller.dart';
import '../theme/trail_theme.dart';
import 'trail_icons.dart';
import 'trail_widgets.dart';

/// Opens the options sheet: appearance, distance units and sign out.
Future<void> showOptionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // The sheet paints its own background from the current theme, so it
    // follows a theme change made while it is open.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => const _OptionsSheet(),
  );
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = TrailColors.of(context);
        return Container(
          decoration: BoxDecoration(
            color: c.paper,
            border: Border(
              top: BorderSide(color: c.inkSoft, width: strokeLine),
              left: BorderSide(color: c.inkSoft, width: strokeLine),
              right: BorderSide(color: c.inkSoft, width: strokeLine),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(radiusMd),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Options', style: TrailText.titleMd(c)),
                      ),
                      SquareGlyphButton(
                        glyph: '×',
                        semanticLabel: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LabelText('Appearance'),
                  const SizedBox(height: 8),
                  SegmentedToggle<ThemeMode>(
                    value: settings.mode,
                    onChanged: settings.setMode,
                    segments: const [
                      ToggleSegment(
                        value: ThemeMode.light,
                        label: 'Light',
                        icon: TrailIcon.sun,
                      ),
                      ToggleSegment(
                        value: ThemeMode.dark,
                        label: 'Dark',
                        icon: TrailIcon.moon,
                      ),
                      ToggleSegment(
                        value: ThemeMode.system,
                        label: 'Match my device',
                        icon: TrailIcon.device,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LabelText('Distance'),
                  const SizedBox(height: 8),
                  SegmentedToggle<DistanceUnit>(
                    value: settings.units,
                    onChanged: settings.setUnits,
                    segments: const [
                      ToggleSegment(
                        value: DistanceUnit.km,
                        label: 'Kilometers',
                        text: 'km',
                      ),
                      ToggleSegment(
                        value: DistanceUnit.mi,
                        label: 'Miles',
                        text: 'mi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TrailButton(
                    label: 'Sign out',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await SupabaseService().signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
