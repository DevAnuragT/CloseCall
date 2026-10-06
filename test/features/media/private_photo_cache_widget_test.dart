import 'dart:async';

import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/media/presentation/private_photo_widgets.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

void main() {
  late FakeAuth auth;
  late PairingController pairing;
  late FakeMedia repository;
  late MediaController media;

  setUp(() async {
    auth = FakeAuth()..change('me');
    pairing = PairingController(session: auth, repository: FakeCouples());
    await pairing.initialize();
    repository = FakeMedia()..assets = [];
    media = MediaController(pairing: pairing, repository: repository);
  });
  tearDown(() {
    media.dispose();
    pairing.dispose();
    auth.dispose();
  });

  Widget preview({bool compact = false, String id = 'secret-asset-id'}) =>
      MaterialApp(
        home: Scaffold(
          body: PrivatePhotoPreview(
            media: media,
            asset: testAsset(id: id),
            width: 200,
            height: 200,
            compact: compact,
          ),
        ),
      );

  testWidgets(
    'mount displays a real private image with no IDs or write calls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('secret-asset-id'), findsNothing);
      expect(find.bySemanticsLabel('Photo from your partner'), findsOneWidget);
      expect(repository.downloads, ['secret-asset-id']);
      expect(repository.requestIds, isEmpty);
      expect(media.busy, isFalse);
      expect(media.selectedAsset, isNull);
      expect(media.downloadedPhoto, isNull);
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();
      expect(repository.downloads, ['secret-asset-id']);
      semantics.dispose();
    },
  );

  testWidgets('failed preview retries explicitly and never leaks error text', (
    tester,
  ) async {
    repository.downloadFailure = TimeoutException('secret signed URL');
    await tester.pumpWidget(preview());
    await tester.pumpAndSettle();
    expect(find.text('Could not load this private photo.'), findsOneWidget);
    expect(find.textContaining('secret signed URL'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    repository.downloadFailure = null;
    await tester.tap(find.text('Retry photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(repository.downloads, hasLength(2));
  });

  testWidgets(
    'eviction shows explicit load without repeated rebuild downloads',
    (tester) async {
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();
      for (var i = 0; i < 13; i++) {
        await media.loadPhoto(testAsset(id: '$i'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Load photo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();
      expect(repository.downloads, hasLength(14));
      await tester.tap(find.text('Load photo'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(repository.downloads, hasLength(15));
    },
  );

  testWidgets('hidden preview loads only on becoming visible', (tester) async {
    Widget hidden(bool enabled) => MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: enabled,
          child: PrivatePhotoThumbnail(media: media, asset: testAsset()),
        ),
      ),
    );
    await tester.pumpWidget(hidden(false));
    await tester.pump();
    expect(repository.downloads, isEmpty);
    await tester.pumpWidget(hidden(true));
    await tester.pumpAndSettle();
    expect(repository.downloads, ['asset']);
    expect(find.byType(Image), findsOneWidget);
  });
}
