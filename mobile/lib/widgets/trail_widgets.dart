import 'package:flutter/material.dart';

import '../theme/trail_theme.dart';

List<BoxShadow> plateShadow(TrailColors c, {double offset = 3}) => [
      BoxShadow(color: c.ink, offset: Offset(offset, offset), blurRadius: 0),
    ];

/// A square plate with a bold ink outline and a hard offset shadow. The
/// shadow drops away and the plate shifts when pressed. Primary fills with the
/// route color; the plain version sits on paper.
class PlateButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const PlateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  State<PlateButton> createState() => _PlateButtonState();
}

class _PlateButtonState extends State<PlateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    final enabled = widget.onPressed != null;
    final fill = !enabled
        ? c.paperShade
        : widget.primary
            ? c.route
            : c.paper;
    final fg = !enabled
        ? c.inkSoft
        : widget.primary
            ? c.onRoute
            : c.ink;
    final down = enabled && _pressed;
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
        child: Transform.translate(
          offset: down ? const Offset(3, 3) : Offset.zero,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(
                  color: enabled ? c.ink : c.inkFaint, width: strokeBold),
              borderRadius: BorderRadius.circular(radiusSm),
              boxShadow: enabled && !down ? plateShadow(c) : const [],
            ),
            child: Text(
              widget.label.toUpperCase(),
              style: TrailText.button(c).copyWith(color: fg),
            ),
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
            border: Border.all(color: c.ink, width: strokeBold),
            borderRadius: BorderRadius.circular(radiusSm),
            boxShadow: plateShadow(c, offset: 2),
          ),
          child: Text(glyph,
              style: TrailText.body(c).copyWith(fontSize: 26, height: 1)),
        ),
      ),
    );
  }
}

/// The title block: a bold outer line and a hairline inner neatline on the
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
        borderRadius: BorderRadius.circular(radiusSm),
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

/// A square on/off switch: ink outline, route-colored when on.
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
            color: value ? c.route : c.paperShade,
            border: Border.all(color: c.ink, width: strokeBold),
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Container(
            width: 18,
            decoration: BoxDecoration(
              color: c.paper,
              border: Border.all(color: c.ink, width: strokeLine),
              borderRadius: BorderRadius.circular(1),
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
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TrailText.label(TrailColors.of(context)),
      );
}

/// North arrow drawn in ink: two rings and four points, north filled.
class Compass extends StatelessWidget {
  final double size;
  const Compass({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Semantics(
      label: 'North arrow',
      child: CustomPaint(
        size: Size.square(size),
        painter: _CompassPainter(ink: c.ink, paper: c.paper),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color ink;
  final Color paper;
  _CompassPainter({required this.ink, required this.paper});

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 104-unit square centered on the origin.
    final s = size.width / 104;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);

    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeLine
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(
        Offset.zero,
        36,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeHair);
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
        Paint()..color = ink);
    canvas.drawPath(
        kite(const Offset(0, 46), const Offset(6, 6), const Offset(-6, 6)),
        line);
    canvas.drawPath(
        kite(const Offset(-46, 0), const Offset(-6, -6), const Offset(-6, 6)),
        line);
    canvas.drawPath(
        kite(const Offset(46, 0), const Offset(6, -6), const Offset(6, 6)),
        line);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.ink != ink || old.paper != paper;
}

/// Grayscale-and-tint filter that turns the colored OpenStreetMap tiles into
/// ink on paper. Day tiles settle on the paper tone; night tiles invert onto
/// the dark paper.
ColorFilter inkTileFilter(Brightness brightness) {
  const r = 0.299, g = 0.587, b = 0.114;
  if (brightness == Brightness.dark) {
    const k = 0.7;
    return ColorFilter.matrix([
      -k * r, -k * g, -k * b, 0, k * 255 + 12,
      -k * r, -k * g, -k * b, 0, k * 255 + 10,
      -k * r, -k * g, -k * b, 0, k * 255 + 4,
      0, 0, 0, 1, 0,
    ]);
  }
  const k = 0.62;
  return const ColorFilter.matrix([
    k * r, k * g, k * b, 0, 90,
    k * r, k * g, k * b, 0, 89,
    k * r, k * g, k * b, 0, 84,
    0, 0, 0, 1, 0,
  ]);
}
