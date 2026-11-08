import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../theme/trail_theme.dart';
import 'trail_widgets.dart';

/// Opens the options sheet: choose light, dark, or match the device.
Future<void> showOptionsSheet(BuildContext context, ThemeController controller) {
  final c = TrailColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.paper,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: c.inkSoft, width: strokeLine),
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(radiusMd)),
    ),
    builder: (_) => _OptionsSheet(controller: controller),
  );
}

class _OptionsSheet extends StatelessWidget {
  final ThemeController controller;
  const _OptionsSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = TrailColors.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('Options', style: TrailText.titleMd(c))),
                    SquareGlyphButton(
                      glyph: '×',
                      semanticLabel: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const LabelText('Appearance'),
                const SizedBox(height: 8),
                _Choice(
                  label: 'Light',
                  selected: controller.mode == ThemeMode.light,
                  onTap: () => controller.setMode(ThemeMode.light),
                ),
                _Choice(
                  label: 'Dark',
                  selected: controller.mode == ThemeMode.dark,
                  onTap: () => controller.setMode(ThemeMode.dark),
                ),
                _Choice(
                  label: 'Match my device',
                  selected: controller.mode == ThemeMode.system,
                  onTap: () => controller.setMode(ThemeMode.system),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? c.washRoute : c.paper,
            border: Border.all(
                color: selected ? c.route : Colors.transparent,
                width: strokeLine),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.route : Colors.transparent,
                  border: Border.all(
                      color: selected ? c.route : c.inkSoft,
                      width: strokeBold),
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: TrailText.body(c)),
            ],
          ),
        ),
      ),
    );
  }
}
