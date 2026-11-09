import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The small set of line icons Trail uses, drawn as thin round-capped
/// strokes on a 24-unit square so they sit with the rest of the ink linework.
enum TrailIcon {
  back,
  close,
  locate,
  info,
  person,
  sun,
  moon,
  device,
  play,
  stop,
}

class TrailIconView extends StatelessWidget {
  final TrailIcon icon;
  final Color color;
  final double size;

  const TrailIconView(
    this.icon, {
    super.key,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(icon, color));
}

class _IconPainter extends CustomPainter {
  final TrailIcon icon;
  final Color color;
  _IconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (icon) {
      case TrailIcon.back:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 5)
            ..lineTo(7.5, 12)
            ..lineTo(14.5, 19),
          line,
        );
      case TrailIcon.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), line);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), line);
      case TrailIcon.locate:
        canvas.drawCircle(const Offset(12, 12), 6, line);
        canvas.drawCircle(const Offset(12, 12), 1.8, fill);
        for (final tick in const [
          [Offset(12, 2.5), Offset(12, 5.5)],
          [Offset(12, 18.5), Offset(12, 21.5)],
          [Offset(2.5, 12), Offset(5.5, 12)],
          [Offset(18.5, 12), Offset(21.5, 12)],
        ]) {
          canvas.drawLine(tick[0], tick[1], line);
        }
      case TrailIcon.info:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16.5), line);
        canvas.drawCircle(const Offset(12, 7.8), 1.1, fill);
      case TrailIcon.person:
        canvas.drawCircle(const Offset(12, 8.2), 3.8, line);
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 20)
            ..cubicTo(4.8, 15.4, 8, 13.4, 12, 13.4)
            ..cubicTo(16, 13.4, 19.2, 15.4, 19.2, 20),
          line,
        );
      case TrailIcon.sun:
        canvas.drawCircle(const Offset(12, 12), 4, line);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(12 + 7 * math.cos(a), 12 + 7 * math.sin(a)),
            Offset(12 + 9.5 * math.cos(a), 12 + 9.5 * math.sin(a)),
            line,
          );
        }
      case TrailIcon.moon:
        canvas.drawPath(
          Path()
            ..moveTo(19.5, 14.5)
            ..arcToPoint(
              const Offset(9.5, 4.5),
              radius: const Radius.circular(8),
              clockwise: false,
            )
            ..arcToPoint(
              const Offset(19.5, 14.5),
              radius: const Radius.circular(6.5),
              clockwise: true,
            ),
          line,
        );
      case TrailIcon.device:
        // A circle with its right half filled: follows the device, light or dark.
        canvas.drawCircle(const Offset(12, 12), 8, line);
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..arcToPoint(const Offset(12, 20), radius: const Radius.circular(8))
            ..close(),
          fill,
        );
      case TrailIcon.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5.5)
            ..lineTo(18.5, 12)
            ..lineTo(8, 18.5)
            ..close(),
          line,
        );
      case TrailIcon.stop:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6.5, 6.5, 11, 11),
            const Radius.circular(1.5),
          ),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}
