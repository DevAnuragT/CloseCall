import 'package:closecall/features/widget/presentation/editor/editor_element.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WidgetEditorController c;
  var notifications = 0;

  setUp(() {
    c = WidgetEditorController();
    notifications = 0;
    c.addListener(() => notifications++);
  });

  tearDown(() => c.dispose());

  group('drawing', () {
    test('a multi-point stroke commits on end', () {
      c.startStroke(const Offset(0, 0));
      c.extendStroke(const Offset(10, 10));
      c.extendStroke(const Offset(20, 5));
      expect(c.activeStroke, isNotNull);
      c.endStroke();
      expect(c.activeStroke, isNull);
      expect(c.elements, hasLength(1));
      expect(c.elements.single, isA<StrokeElement>());
    });

    test('a single-point tap-stroke is dropped as noise', () {
      c.startStroke(const Offset(5, 5));
      c.endStroke();
      expect(c.elements, isEmpty);
    });
  });

  group('text & stickers', () {
    test('addText trims and ignores empty', () {
      c.addText('  hi  ', const Offset(1, 1));
      c.addText('   ', const Offset(2, 2));
      expect(c.elements, hasLength(1));
      expect((c.elements.single as TextElement).text, 'hi');
    });

    test('addSticker appends a sticker element', () {
      c.addSticker('❤️', const Offset(3, 3));
      expect(c.elements.single, isA<StickerElement>());
    });
  });

  group('history', () {
    test('undo removes the last element', () {
      c.addSticker('✨', const Offset(0, 0));
      c.addText('note', const Offset(1, 1));
      c.undo();
      expect(c.elements, hasLength(1));
      expect(c.elements.single, isA<StickerElement>());
    });

    test('clear empties everything', () {
      c.addSticker('✨', const Offset(0, 0));
      c.clear();
      expect(c.isEmpty, isTrue);
      expect(c.canUndo, isFalse);
    });

    test('undo/clear on empty do not over-notify', () {
      final before = notifications;
      c.undo();
      c.clear();
      expect(notifications, before);
    });
  });

  group('tool/color setters notify', () {
    test('changing tool notifies once; same value does not', () {
      final before = notifications;
      c.tool = EditorTool.sticker;
      c.tool = EditorTool.sticker;
      expect(notifications, before + 1);
    });

    test('changing color notifies', () {
      final before = notifications;
      c.color = const Color(0xFF123456);
      expect(notifications, before + 1);
    });
  });
}
