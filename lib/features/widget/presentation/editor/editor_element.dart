import 'package:flutter/widgets.dart';

/// One editable layer on top of the widget photo. Sealed so the painter and
/// undo stack can switch over every kind exhaustively.
sealed class EditorElement {
  const EditorElement();
}

/// A freehand pen stroke.
class StrokeElement extends EditorElement {
  const StrokeElement({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;

  StrokeElement copyWith({List<Offset>? points}) =>
      StrokeElement(points: points ?? this.points, color: color, width: width);
}

/// A handwritten/typed text note placed at [position] (top-left anchor).
class TextElement extends EditorElement {
  const TextElement({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
}

/// An emoji sticker centered at [position].
class StickerElement extends EditorElement {
  const StickerElement({
    required this.emoji,
    required this.position,
    required this.size,
  });

  final String emoji;
  final Offset position;
  final double size;
}
