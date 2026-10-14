import 'dart:async';

import 'package:closecall/core/theme/app_theme.dart';
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

Future<void> _pumpEditor(
  WidgetTester tester,
  PairingController controller, {
  double width = 400,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: NicknameEditor(controller: controller),
        ),
      ),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
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

  testWidgets('editor supports cancel and clears drafts on scope change', (
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
    await _pumpEditor(tester, controller, width: 320, textScale: 2);
    expect(controller.canSaveNicknames, isTrue);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
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
    expect(find.byKey(const Key('own-nickname')), findsNothing);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('own-nickname')))
          .controller!
          .text,
      'Me',
    );
    await tester.enterText(
      find.byKey(const Key('own-nickname')),
      'Private draft',
    );
    auth.change('other');
    await tester.pump();
    expect(find.text('Me'), findsNothing);
    expect(find.text('Love'), findsNothing);
    expect(find.text('Private draft'), findsNothing);
    expect(find.byKey(const Key('save-nicknames')), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('edit-nicknames')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
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
    await _pumpEditor(tester, controller);
    expect(find.text('private legacy label'), findsNothing);
    expect(
      find.text('Pair with your partner to add nicknames.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('own-nickname')), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('edit-nicknames')))
          .onPressed,
      isNull,
    );
    controller.dispose();
    auth.dispose();
  });

  testWidgets('identity card and editor fit 320px at double text scale', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()
      ..couple = Couple(
        id: 'c1',
        memberIds: ['me', 'partner'],
        ownNickname: 'Alexandra my favourite person',
        partnerNickname: 'A very long and lovely partner nickname',
      );
    final controller = await _controller(auth, repo);
    final semantics = tester.ensureSemantics();
    await _pumpEditor(tester, controller, width: 320, textScale: 2);
    expect(find.text(repo.couple.ownNickname!), findsOneWidget);
    expect(find.text(repo.couple.partnerNickname!), findsOneWidget);
    expect(
      find.text(
        'Just for you. These nicknames are personal and aren’t visible to your partner.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('You: ${repo.couple.ownNickname}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Your partner: ${repo.couple.partnerNickname}'),
      findsOneWidget,
    );
    final edit = find.byKey(const Key('edit-nicknames'));
    expect(tester.getSize(edit).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, edit);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('own-nickname'))),
      ).scale(14),
      28,
    );
    final save = find.byKey(const Key('save-nicknames'));
    final cancel = find.byKey(const Key('cancel-nicknames'));
    await tester.ensureVisible(save);
    expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    // Closing a pristine form is still possible.
    await _tapVisible(tester, cancel);
    expect(find.byKey(const Key('own-nickname')), findsNothing);
    expect(repo.writes, 0);
    semantics.dispose();
    controller.dispose();
    auth.dispose();
  });

  testWidgets(
    'saving disables edits, failure retains draft, retry confirms names',
    (tester) async {
      final auth = FakeAuth();
      final repo = _NicknameCouples()..pending = Completer<Couple>();
      final controller = await _controller(auth, repo);
      await _pumpEditor(tester, controller, width: 320, textScale: 2);
      await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
      await tester.enterText(find.byKey(const Key('own-nickname')), 'Sunshine');
      await tester.enterText(
        find.byKey(const Key('partner-nickname')),
        'Moonbeam',
      );
      final save = find.byKey(const Key('save-nicknames'));
      await _tapVisible(tester, save);
      expect(find.text('Saving nicknames…'), findsOneWidget);
      expect(find.text('Nicknames saved.'), findsNothing);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(
        tester.widget<TextField>(find.byKey(const Key('own-nickname'))).enabled,
        isFalse,
      );
      expect(repo.writes, 1);
      repo.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save nicknames. Try again.'), findsOneWidget);
      expect(find.text('Try saving again'), findsOneWidget);
      expect(find.text('Nicknames saved.'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('own-nickname')))
            .controller!
            .text,
        'Sunshine',
      );
      expect(tester.takeException(), isNull);
      repo.pending = null;
      await _tapVisible(tester, save);
      expect(repo.writes, 2);
      expect(repo.own, 'Sunshine');
      expect(repo.partner, 'Moonbeam');
      expect(find.text('Sunshine'), findsOneWidget);
      expect(find.text('Moonbeam'), findsOneWidget);
      expect(find.text('Nicknames saved.'), findsOneWidget);
      expect(find.byKey(const Key('own-nickname')), findsNothing);
      expect(tester.takeException(), isNull);
      controller.dispose();
      auth.dispose();
    },
  );

  testWidgets('cancel during saving suppresses late confirmation feedback', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()..pending = Completer<Couple>();
    final controller = await _controller(auth, repo);
    await _pumpEditor(tester, controller);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
    await tester.enterText(find.byKey(const Key('own-nickname')), 'Draft name');
    await _tapVisible(tester, find.byKey(const Key('save-nicknames')));
    await _tapVisible(tester, find.byKey(const Key('cancel-nicknames')));
    expect(find.byKey(const Key('own-nickname')), findsNothing);
    expect(find.text('Draft name'), findsNothing);
    repo.pending!.complete(repo.couple.copyWith(ownNickname: 'Draft name'));
    await tester.pumpAndSettle();
    expect(find.text('Nicknames saved.'), findsNothing);
    expect(find.text('Draft name'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('own-nickname')))
          .controller!
          .text,
      'Draft name',
    );
    controller.dispose();
    auth.dispose();
  });

  testWidgets('cancel after a failed save restores names and clears error', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = _NicknameCouples()
      ..failure = StateError('offline')
      ..couple = Couple(
        id: 'c1',
        memberIds: ['me', 'partner'],
        ownNickname: 'Me',
        partnerNickname: 'Love',
      );
    final controller = await _controller(auth, repo);
    await _pumpEditor(tester, controller);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
    await tester.enterText(find.byKey(const Key('own-nickname')), 'Draft name');
    await _tapVisible(tester, find.byKey(const Key('save-nicknames')));
    expect(find.text('Could not save nicknames. Try again.'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('cancel-nicknames')));
    expect(find.text('Could not save nicknames. Try again.'), findsNothing);
    expect(find.text('Me'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('edit-nicknames')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('own-nickname')))
          .controller!
          .text,
      'Me',
    );
    expect(repo.writes, 1);
    controller.dispose();
    auth.dispose();
  });
}
