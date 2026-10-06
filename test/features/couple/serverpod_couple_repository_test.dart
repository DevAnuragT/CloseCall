import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/data/serverpod_couple_repository.dart';
import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter_test/flutter_test.dart';

api.PairingState state({String? code = 'ABC123', bool paired = false}) =>
    api.PairingState(
      coupleId: 'couple-1',
      memberIds: paired ? ['me', 'partner'] : ['me'],
      partnerNickname: 'Love',
      ownNickname: 'Me',
      anniversary: DateTime(2024, 2, 3),
      themeKey: 'blush',
      pairingCode: code,
    );

void main() {
  test('maps DTO fields, invite code, and nullable current couple', () async {
    api.PairingState? current = state();
    final repository = ServerpodCoupleRepository.withCalls(
      userId: () => 'me',
      create: () async => state(),
      join: (_) async => state(paired: true, code: null),
      current: () async => current,
    );
    final created = await repository.createCouple('me');
    expect(created.code, 'ABC123');
    expect(created.couple.id, 'couple-1');
    expect(created.couple.memberIds, ['me']);
    expect(created.couple.partnerNickname, 'Love');
    expect(created.couple.ownNickname, 'Me');
    expect(created.couple.anniversary, DateTime(2024, 2, 3).toUtc());
    expect(created.couple.themeKey, 'blush');
    expect(
      () => created.couple.memberIds.add('intruder'),
      throwsUnsupportedError,
    );
    expect(repository.currentInviteCode, 'ABC123');
    final joined = await repository.joinByCode('me', 'OTHER1');
    expect(joined.isComplete, isTrue);
    expect(repository.currentInviteCode, isNull);
    await repository.coupleForUser('me');
    expect(repository.currentInviteCode, 'ABC123');
    current = null;
    expect(await repository.coupleForUser('me'), isNull);
    expect(repository.currentInviteCode, isNull);
  });

  test('maps and scopes the optional nickname mutation callback', () async {
    String? seenCouple;
    String? seenOwn;
    String? seenPartner;
    final repository = ServerpodCoupleRepository.withCalls(
      userId: () => 'me',
      create: () async => state(),
      join: (_) async => state(paired: true, code: null),
      current: () async => state(paired: true, code: null),
      updateNicknames: (couple, own, partner) async {
        seenCouple = couple;
        seenOwn = own;
        seenPartner = partner;
        return state(paired: true, code: null);
      },
    );
    final result = await repository.saveNicknames(
      'me',
      'couple-1',
      ownNickname: 'Me',
      partnerNickname: 'Love',
    );
    expect(result.ownNickname, 'Me');
    expect(seenCouple, 'couple-1');
    expect(seenOwn, 'Me');
    expect(seenPartner, 'Love');
    await expectLater(
      repository.saveNicknames('other', 'couple-1'),
      throwsA(isA<StateError>()),
    );
  });

  test('translates nickname server validation and scope errors', () async {
    for (final code in ['invalid_nickname', 'not_paired']) {
      final repository = ServerpodCoupleRepository.withCalls(
        userId: () => 'me',
        create: () async => state(),
        join: (_) async => state(),
        current: () async => state(paired: true, code: null),
        updateNicknames: (_, _, _) async =>
            throw api.PairingFailure(code: code),
      );
      await expectLater(
        repository.saveNicknames('me', 'couple-1'),
        throwsA(isA<Exception>()),
      );
    }
  });

  test(
    'only known typed PairingFailure codes become PairingException',
    () async {
      final codes = {
        'invalid_code': PairingError.invalidCode,
        'code_not_found': PairingError.codeNotFound,
        'already_paired': PairingError.alreadyPaired,
        'cannot_pair_with_self': PairingError.cannotPairWithSelf,
      };
      for (final entry in codes.entries) {
        final repository = ServerpodCoupleRepository.withCalls(
          userId: () => 'me',
          create: () async => throw api.PairingFailure(code: entry.key),
          join: (_) async => throw api.PairingFailure(code: entry.key),
          current: () async => throw api.PairingFailure(code: entry.key),
        );
        final matcher = isA<PairingException>().having(
          (e) => e.error,
          'error',
          entry.value,
        );
        await expectLater(repository.createCouple('me'), throwsA(matcher));
        await expectLater(
          repository.joinByCode('me', 'ABC123'),
          throwsA(matcher),
        );
        await expectLater(repository.coupleForUser('me'), throwsA(matcher));
      }
    },
  );

  test(
    'transport and unknown typed failures retain their original identity',
    () async {
      for (final failure in [
        StateError('transport code_not_found'),
        api.PairingFailure(code: 'future_server_error'),
      ]) {
        final repository = ServerpodCoupleRepository.withCalls(
          userId: () => 'me',
          create: () async => throw failure,
          join: (_) async => throw failure,
          current: () async => throw failure,
        );
        await expectLater(
          repository.createCouple('me'),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.joinByCode('me', 'ABC123'),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.coupleForUser('me'),
          throwsA(same(failure)),
        );
      }
    },
  );

  test('caller cannot supply a different user identity to any RPC', () async {
    var calls = 0;
    final repository = ServerpodCoupleRepository.withCalls(
      userId: () => 'me',
      create: () async {
        calls++;
        return state();
      },
      join: (_) async {
        calls++;
        return state();
      },
      current: () async {
        calls++;
        return state();
      },
    );
    await expectLater(repository.createCouple('other'), throwsStateError);
    await expectLater(
      repository.joinByCode('other', 'ABC123'),
      throwsStateError,
    );
    await expectLater(repository.coupleForUser('other'), throwsStateError);
    expect(calls, 0);
  });
}
