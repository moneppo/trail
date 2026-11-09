import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/trail_theme.dart';
import 'trail_icons.dart';

/// A thin-outlined button with a small corner radius and no shadow. The
/// outline and label are always the text color. Primary carries a light wash
/// of the route hue behind them; the plain version sits on paper.
class TrailButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const TrailButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  State<TrailButton> createState() => _TrailButtonState();
}

class _TrailButtonState extends State<TrailButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    final enabled = widget.onPressed != null;
    final down = enabled && _pressed;

    final Color fill;
    final Color border;
    final Color fg;
    if (!enabled) {
      fill = c.paperShade;
      border = c.inkFaint;
      fg = c.inkSoft;
    } else if (widget.primary) {
      fill = c.washRoute;
      border = c.ink;
      fg = c.ink;
    } else {
      fill = down ? c.paperShade : c.paper;
      border = c.ink;
      fg = c.ink;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border, width: strokeLine),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: TrailText.button(c).copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}

/// A 44px square button holding one glyph, for closing a sheet or going back.
class SquareGlyphButton extends StatelessWidget {
  final String glyph;
  final String semanticLabel;
  final VoidCallback onPressed;

  const SquareGlyphButton({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.paper,
            border: Border.all(color: c.inkSoft, width: strokeLine),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Text(
            glyph,
            style: TrailText.body(c).copyWith(fontSize: 26, height: 1),
          ),
        ),
      ),
    );
  }
}

/// A round icon button that floats over a map: paper fill, thin outline.
class FloatingIconButton extends StatelessWidget {
  final TrailIcon icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  const FloatingIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.paper,
            shape: BoxShape.circle,
            border: Border.all(color: c.inkSoft, width: strokeLine),
          ),
          child: TrailIconView(icon, color: c.ink),
        ),
      ),
    );
  }
}

/// A large round button with an icon and a label underneath, for the main
/// action on the walk screen: Start, then Stop.
class RoundActionButton extends StatefulWidget {
  final TrailIcon icon;
  final String label;
  final VoidCallback? onPressed;

  const RoundActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<RoundActionButton> createState() => _RoundActionButtonState();
}

class _RoundActionButtonState extends State<RoundActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !enabled
                    ? c.paperShade
                    : (_pressed ? c.paperShade : c.washRoute),
                border: Border.all(
                  color: enabled ? c.ink : c.inkFaint,
                  width: strokeLine,
                ),
              ),
              child: TrailIconView(
                widget.icon,
                color: enabled ? c.ink : c.inkSoft,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label.toUpperCase(),
              style: TrailText.button(c)
                  .copyWith(color: enabled ? c.ink : c.inkSoft, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title block: a thin outer line and a hairline inner neatline on the
/// same paper as the page.
class Cartouche extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Cartouche({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.ink, width: strokeBold),
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: c.ink, width: strokeHair),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        child: child,
      ),
    );
  }
}

/// A square on/off switch: a wash of the route hue when on.
class TrailSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  const TrailSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 52,
          height: 28,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? c.washRoute : c.paperShade,
            border: Border.all(color: c.ink, width: strokeLine),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Container(
            width: 20,
            decoration: BoxDecoration(
              color: value ? c.route : c.paper,
              border: Border.all(
                color: value ? c.route : c.inkSoft,
                width: strokeLine,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link: candidate blue, dashed underline.
class TrailLink extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const TrailLink({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Text(
            text,
            style: TrailText.bodySm(c).copyWith(
              color: c.candidate,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
              decorationColor: c.candidate,
            ),
          ),
        ),
      ),
    );
  }
}

/// A line of uppercase label text.
class LabelText extends StatelessWidget {
  final String text;
  const LabelText(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TrailText.label(TrailColors.of(context)));
}

/// North arrow drawn in ink: two rings and four points, north in the route
/// color. [bearing] is flutter_map's camera rotation in degrees, which turns
/// the map clockwise, so the arrow turns clockwise by the same amount to keep
/// pointing at north. Give [onTap] to make it a button that straightens the map.
class Compass extends StatelessWidget {
  final double size;
  final double bearing;
  final VoidCallback? onTap;

  const Compass({super.key, this.size = 104, this.bearing = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    Widget art = Transform.rotate(
      angle: bearing * math.pi / 180,
      child: CustomPaint(
        size: Size.square(size),
        painter: _CompassPainter(ink: c.ink, paper: c.paper, north: c.route),
      ),
    );
    if (onTap != null) {
      art = GestureDetector(onTap: onTap, child: art);
    }
    return Semantics(
      label: onTap != null ? 'Point the map north' : 'North arrow',
      button: onTap != null,
      child: art,
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color ink;
  final Color paper;
  final Color north;
  _CompassPainter({
    required this.ink,
    required this.paper,
    required this.north,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 104-unit square centered on the origin.
    final s = size.width / 104;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);

    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(
      Offset.zero,
      36,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
    canvas.drawCircle(Offset.zero, 29, Paint()..color = paper);
    canvas.drawCircle(Offset.zero, 29, line);

    // Each point is a kite: the tip, two shoulders and the center.
    Path kite(Offset tip, Offset a, Offset b) => Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(0, 0)
      ..lineTo(b.dx, b.dy)
      ..close();

    canvas.drawPath(
      kite(const Offset(0, -46), const Offset(6, -6), const Offset(-6, -6)),
      Paint()..color = north,
    );
    canvas.drawPath(
      kite(const Offset(0, 46), const Offset(6, 6), const Offset(-6, 6)),
      line,
    );
    canvas.drawPath(
      kite(const Offset(-46, 0), const Offset(-6, -6), const Offset(-6, 6)),
      line,
    );
    canvas.drawPath(
      kite(const Offset(46, 0), const Offset(6, -6), const Offset(6, 6)),
      line,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.ink != ink || old.paper != paper || old.north != north;
}

/// Grayscale-and-tint filter that turns the colored OpenStreetMap tiles into
/// ink on paper. Day tiles settle on the paper tone; night tiles invert onto
/// the dark paper.
ColorFilter inkTileFilter(Brightness brightness) {
  const r = 0.299, g = 0.587, b = 0.114;
  if (brightness == Brightness.dark) {
    const k = 0.7;
    return ColorFilter.matrix([
      -k * r,
      -k * g,
      -k * b,
      0,
      k * 255 + 12,
      -k * r,
      -k * g,
      -k * b,
      0,
      k * 255 + 10,
      -k * r,
      -k * g,
      -k * b,
      0,
      k * 255 + 4,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
  const k = 0.62;
  return const ColorFilter.matrix([
    k * r,
    k * g,
    k * b,
    0,
    90,
    k * r,
    k * g,
    k * b,
    0,
    89,
    k * r,
    k * g,
    k * b,
    0,
    84,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// One choice in a [SegmentedToggle]: an icon or a short text, plus the full
/// name used by screen readers.
class ToggleSegment<T> {
  final T value;
  final String label;
  final TrailIcon? icon;
  final String? text;

  const ToggleSegment({
    required this.value,
    required this.label,
    this.icon,
    this.text,
  });
}

/// A row of connected choices where exactly one is selected, shown as icons
/// or short text. The chosen segment takes a light wash and an ink icon.
class SegmentedToggle<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final List<ToggleSegment<T>> segments;

  const SegmentedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.inkSoft, width: strokeLine),
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusSm - strokeLine),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                Container(width: strokeLine, height: 44, color: c.inkSoft),
              Expanded(child: _segment(c, segments[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(TrailColors c, ToggleSegment<T> segment) {
    final selected = segment.value == value;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: segment.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(segment.value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          color: selected ? c.washRoute : c.paper,
          child: segment.icon != null
              ? TrailIconView(
                  segment.icon!,
                  color: selected ? c.ink : c.inkSoft,
                )
              : Text(
                  segment.text ?? segment.label,
                  style: TrailText.button(
                    c,
                  ).copyWith(color: selected ? c.ink : c.inkSoft, fontSize: 15),
                ),
        ),
      ),
    );
  }
}
