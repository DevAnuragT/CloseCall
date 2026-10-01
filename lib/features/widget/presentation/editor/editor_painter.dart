import 'package:flutter/material.dart';

import 'editor_element.dart';

/// Paints the editor's layer stack over whatever is behind it. Pure function
/// of its inputs so the editor surface can be composited to an image.
class EditorPainter extends CustomPainter {
  EditorPainter({required this.elements, this.activeStroke});

  final List<EditorElement> elements;
  final StrokeElement? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      _paintElement(canvas, element);
    }
    final active = activeStroke;
    if (active != null) _paintStroke(canvas, active);
  }

  void _paintElement(Canvas canvas, EditorElement element) {
    switch (element) {
      case StrokeElement():
        _paintStroke(canvas, element);
      case TextElement():
        _paintText(
          canvas,
          element.text,
          element.position,
          element.color,
          element.fontSize,
        );
      case StickerElement():
        // Centered emoji.
        final tp = _layout(element.emoji, const Color(0xFF000000), element.size);
        tp.paint(
          canvas,
          element.position - Offset(tp.width / 2, tp.height / 2),
        );
    }
  }

  void _paintStroke(Canvas canvas, StrokeElement stroke) {
    if (stroke.points.length < 2) return;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final p in stroke.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    _layout(text, color, fontSize).paint(canvas, position);
  }

  TextPainter _layout(String text, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant EditorPainter old) =>
      old.elements != elements || old.activeStroke != activeStroke;
}
