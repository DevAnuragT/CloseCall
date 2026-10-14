import 'package:closecall/features/widget/presentation/editor/editor_element.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_controller.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, WidgetEditorController c) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(home: WidgetEditorScreen(controller: c)),
    );
  }

  testWidgets('dragging on the canvas in draw mode adds a stroke', (
    tester,
  ) async {
    final c = WidgetEditorController();
    await pumpEditor(tester, c);

    await tester.drag(
      find.byKey(const Key('editor-canvas')),
      const Offset(80, 40),
    );
    await tester.pump();

    expect(c.elements, hasLength(1));
    expect(c.elements.single, isA<StrokeElement>());
  });

  testWidgets('tapping in sticker mode places the selected sticker', (
    tester,
  ) async {
    final c = WidgetEditorController()..tool = EditorTool.sticker;
    await pumpEditor(tester, c);

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('editor-canvas'))),
    );
    await tester.pump();

    expect(c.elements.single, isA<StickerElement>());
  });

  testWidgets('text tool: tap -> dialog -> add places a text element', (
    tester,
  ) async {
    final c = WidgetEditorController()..tool = EditorTool.text;
    await pumpEditor(tester, c);

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('editor-canvas'))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('editor-text-field')),
      'love you',
    );
    await tester.tap(find.byKey(const Key('editor-text-add')));
    await tester.pumpAndSettle();

    expect(c.elements.single, isA<TextElement>());
    expect((c.elements.single as TextElement).text, 'love you');
  });

  testWidgets('undo button removes the last element', (tester) async {
    final c = WidgetEditorController()
      ..addSticker('✨', const Offset(10, 10))
      ..addSticker('❤️', const Offset(20, 20));
    await pumpEditor(tester, c);

    await tester.tap(find.byKey(const Key('editor-undo')));
    await tester.pump();

    expect(c.elements, hasLength(1));
  });

  testWidgets('export produces non-empty PNG bytes', (tester) async {
    final c = WidgetEditorController()..addSticker('❤️', const Offset(50, 50));
    await pumpEditor(tester, c);

    final state =
        tester.state<State<WidgetEditorScreen>>(find.byType(WidgetEditorScreen))
            as dynamic;

    await tester.runAsync(() async {
      final bytes = await state.export(pixelRatio: 1.0);
      expect(bytes, isNotNull);
      expect(bytes!.lengthInBytes, greaterThan(0));
    });
  });
}
