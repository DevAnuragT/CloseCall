import 'dart:async';

import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/nickname_editor.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

class _NicknameCouples implements CoupleRepository, NicknameRepository {
  Couple couple = Couple(id: 'c1', memberIds: ['me', 'partner']);
  Completer<Couple>? pending;
  Object? failure;
  int writes = 0;
  String? own;
  String? partner;

  @override
  Future<Couple?> coupleForUser(String id) async => id == 'me' ? couple : null;

  @override
  Future<PairingResult> createCouple(String userId) async =>
      throw UnimplementedError();

  @override
  Future<Couple> joinByCode(String userId, String code) async => couple;

  @override
  Future<Couple> saveNicknames(
    String userId,
    String coupleId, {
    String? ownNickname,
    String? partnerNickname,
  }) async {
    writes++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    own = ownNickname;
    partner = partnerNickname;
    return couple = couple.copyWith(
      ownNickname: ownNickname,
      partnerNickname: partnerNickname,
    );
  }
}

Future<PairingController> _controller(
  FakeAuth auth,
  _NicknameCouples repository,
) async {
  auth.change('me');
  final controller = PairingController(session: auth, repository: repository);
  await controller.initialize();
  return controller;
}

void main() {
  test('late nickname result cannot cross an account or couple', () async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()..pending = Completer<Couple>();
    final controller = await _controller(auth, repo);
    final save = controller.saveNicknames(
      ownNickname: 'Me',
      partnerNickname: 'Love',
    );
    await Future<void>.delayed(Duration.zero);
    auth.change('someone-else');
    repo.pending!.complete(repo.couple.copyWith(ownNickname: 'wrong'));
    expect(await save, isFalse);
    expect(controller.couple, isNull);
    expect(controller.nicknameError, isNull);
    controller.dispose();
    auth.dispose();
  });

  test('nickname failure is isolated and retry reuses payload', () async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()..failure = StateError('offline');
    final controller = await _controller(auth, repo);
    expect(
      await controller.saveNicknames(
        ownNickname: 'Me',
        partnerNickname: 'Love',
      ),
      isFalse,
    );
    expect(controller.nicknameError, isA<StateError>());
    expect(controller.error, isNull);
    repo.failure = null;
    expect(await controller.retryNicknames(), isTrue);
    expect(repo.own, 'Me');
    expect(repo.partner, 'Love');
    controller.dispose();
    auth.dispose();
  });

  test('dispose ignores a pending nickname write', () async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()..pending = Completer<Couple>();
    final controller = await _controller(auth, repo);
    final save = controller.saveNicknames(
      ownNickname: 'Me',
      partnerNickname: 'Love',
    );
    controller.dispose();
    repo.pending!.complete(repo.couple);
    expect(await save, isFalse);
    auth.dispose();
  });

  testWidgets('editor supports cancel, stale scope, and large text scale', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()
      ..couple = Couple(
        id: 'c1',
        memberIds: ['me', 'partner'],
        ownNickname: 'Me',
        partnerNickname: 'Love',
      );
    final controller = await _controller(auth, repo);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NicknameEditor(controller: controller),
            ),
          ),
        ),
      ),
    );
    expect(controller.canSaveNicknames, isTrue);
    expect(find.text('Your nickname'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('own-nickname')), 'Changed');
    await tester.pump();
    expect(controller.busy, isFalse);
    expect(controller.nicknameSaving, isFalse);
    expect(
      tester.widget<TextField>(find.byKey(const Key('own-nickname'))).enabled,
      isTrue,
    );
    final cancel = find.byKey(const Key('cancel-nicknames'));
    await tester.ensureVisible(cancel);
    expect(tester.widget<TextButton>(cancel).onPressed, isNotNull);
    await tester.tap(cancel);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('own-nickname')))
          .controller!
          .text,
      'Me',
    );
    auth.change('other');
    await tester.pump();
    expect(find.byKey(const Key('save-nicknames')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-nicknames')))
          .onPressed,
      isNull,
    );
    controller.dispose();
    auth.dispose();
  });

  testWidgets('unpaired editor is disabled without showing labels', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()
      ..couple = Couple(
        id: 'pending',
        memberIds: ['me'],
        partnerNickname: 'private legacy label',
      );
    final controller = await _controller(auth, repo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NicknameEditor(controller: controller)),
      ),
    );
    final own = tester.widget<TextField>(find.byKey(const Key('own-nickname')));
    final partner = tester.widget<TextField>(
      find.byKey(const Key('partner-nickname')),
    );
    expect(own.enabled, isFalse);
    expect(partner.enabled, isFalse);
    expect(own.controller!.text, isEmpty);
    expect(partner.controller!.text, isEmpty);
    controller.dispose();
    auth.dispose();
  });
}
