import 'package:flutter/material.dart';

import 'editor_element.dart';

/// The tools the editor can be in.
enum EditorTool { draw, text, sticker }

/// Holds the editable layer stack for the widget photo and exposes the
/// mutations the UI drives. Kept free of rendering so it can be unit tested.
class WidgetEditorController extends ChangeNotifier {
  final List<EditorElement> _elements = [];
  StrokeElement? _activeStroke;

  EditorTool _tool = EditorTool.draw;
  Color _color = const Color(0xFFE8A0A0);
  double _strokeWidth = 6;

  EditorTool get tool => _tool;
  set tool(EditorTool value) {
    if (value == _tool) return;
    _tool = value;
    notifyListeners();
  }

  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    notifyListeners();
  }

  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    if (value == _strokeWidth) return;
    _strokeWidth = value;
    notifyListeners();
  }

  /// Committed layers, oldest first. Excludes the in-progress stroke.
  List<EditorElement> get elements => List.unmodifiable(_elements);

  /// The stroke currently being drawn, if any (for live preview).
  StrokeElement? get activeStroke => _activeStroke;

  bool get isEmpty => _elements.isEmpty && _activeStroke == null;
  bool get canUndo => _elements.isNotEmpty;

  // ── Drawing ──────────────────────────────────────────────────────────────
  void startStroke(Offset point) {
    _activeStroke = StrokeElement(
      points: [point],
      color: _color,
      width: _strokeWidth,
    );
    notifyListeners();
  }

  void extendStroke(Offset point) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    _activeStroke = stroke.copyWith(points: [...stroke.points, point]);
    notifyListeners();
  }

  /// Commits the active stroke. Single-point taps are dropped as noise.
  void endStroke() {
    final stroke = _activeStroke;
    _activeStroke = null;
    if (stroke != null && stroke.points.length > 1) {
      _elements.add(stroke);
    }
    notifyListeners();
  }

  // ── Text & stickers ────────────────────────────────────────────────────
  void addText(String text, Offset position, {double fontSize = 28}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _elements.add(
      TextElement(
        text: trimmed,
        position: position,
        color: color,
        fontSize: fontSize,
      ),
    );
    notifyListeners();
  }

  void addSticker(String emoji, Offset position, {double size = 48}) {
    _elements.add(StickerElement(emoji: emoji, position: position, size: size));
    notifyListeners();
  }

  // ── History ──────────────────────────────────────────────────────────────
  void undo() {
    if (_elements.isEmpty) return;
    _elements.removeLast();
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _elements.clear();
    _activeStroke = null;
    notifyListeners();
  }
}
