import 'dart:convert';
import 'dart:typed_data';

import 'package:closecall/features/widget/presentation/widget_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal valid 1×1 PNG so Image.memory has real bytes to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  late bool? result;

  Future<void> pushPreview(WidgetTester tester, Uint8List bytes) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => WidgetPreviewScreen(photo: bytes),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('previews the photo across widget shapes', (tester) async {
    await pushPreview(tester, _png);
    expect(find.text('How it will look'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Circle'), findsOneWidget);
  });

  testWidgets('confirm returns true and pops', (tester) async {
    await pushPreview(tester, _png);
    await tester.tap(find.byKey(const Key('preview-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('How it will look'), findsNothing);
  });

  testWidgets('keep editing returns false and pops', (tester) async {
    await pushPreview(tester, _png);
    await tester.tap(find.byKey(const Key('preview-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('How it will look'), findsNothing);
  });
}
