import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:closecall/features/media/data/media_repository.dart';
import 'package:closecall/features/media/data/photo_preparation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

void main() {
  testWidgets(
    'prepares picked photo as a bounded PNG without platform plugins',
    (tester) async {
      await tester.runAsync(() async {
        final prepared = await preparePhotoPng(testPng);
        validateUploadPng(prepared);
        expect(prepared.length, lessThanOrEqualTo(maxPhotoBytes));
      });
    },
  );

  testWidgets('oversized source dimensions are resized before upload', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffcc88aa), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2400, 1200);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final prepared = await preparePhotoPng(byteDataBytes(data!));
        validateUploadPng(prepared);
        final header = ByteData.sublistView(prepared);
        expect(header.getUint32(16), 2048);
        expect(header.getUint32(20), 1024);
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
  });

  testWidgets(
    'empty, invalid and encoded source over 20 MiB are explicit failures',
    (tester) async {
      await tester.runAsync(() async {
        await expectLater(preparePhotoPng(Uint8List(0)), throwsFormatException);
        await expectLater(
          preparePhotoPng(Uint8List(20 * 1024 * 1024 + 1)),
          throwsFormatException,
        );
        await expectLater(
          preparePhotoPng(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<Exception>()),
        );
      });
    },
  );
}
