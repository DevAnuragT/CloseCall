import 'dart:math';

import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/data/in_memory_couple_repository.dart';
import 'package:closecall/features/pairing/domain/pairing_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryCoupleRepository repo;

  setUp(() => repo = InMemoryCoupleRepository(random: Random(7)));

  group('createCouple', () {
    test('returns a valid code and an incomplete couple with the user', () async {
      final result = await repo.createCouple('alice');
      expect(PairingCode.isValid(result.code), isTrue);
      expect(result.couple.memberIds, ['alice']);
      expect(result.couple.isComplete, isFalse);
    });

    test('is idempotent while pending (same code returned)', () async {
      final first = await repo.createCouple('alice');
      final second = await repo.createCouple('alice');
      expect(second.code, first.code);
      expect(second.couple.id, first.couple.id);
    });

    test('throws alreadyPaired once the user is in a complete couple', () async {
      final created = await repo.createCouple('alice');
      await repo.joinByCode('bob', created.code);
      expect(
        () => repo.createCouple('alice'),
        throwsA(isA<PairingException>().having(
          (e) => e.error,
          'error',
          PairingError.alreadyPaired,
        )),
      );
    });
  });

  group('joinByCode', () {
    test('completes the couple with both members', () async {
      final created = await repo.createCouple('alice');
      final couple = await repo.joinByCode('bob', created.code);
      expect(couple.memberIds, containsAll(['alice', 'bob']));
      expect(couple.isComplete, isTrue);
    });

    test('accepts the formatted (ABC-DEF) code', () async {
      final created = await repo.createCouple('alice');
      final couple = await repo.joinByCode('bob', PairingCode.format(created.code));
      expect(couple.isComplete, isTrue);
    });

    test('rejects a malformed code', () async {
      expect(
        () => repo.joinByCode('bob', 'nope'),
        throwsA(isA<PairingException>().having(
          (e) => e.error, 'error', PairingError.invalidCode)),
      );
    });

    test('rejects an unknown but well-formed code', () async {
      // A valid-shaped code that was never issued.
      final unused = PairingCode.generate(random: Random(999));
      expect(
        () => repo.joinByCode('bob', unused),
        throwsA(isA<PairingException>().having(
          (e) => e.error, 'error', PairingError.codeNotFound)),
      );
    });

    test('rejects the creator joining their own code', () async {
      final created = await repo.createCouple('alice');
      expect(
        () => repo.joinByCode('alice', created.code),
        throwsA(isA<PairingException>().having(
          (e) => e.error, 'error', PairingError.cannotPairWithSelf)),
      );
    });

    test('consumes the code so it cannot be reused', () async {
      final created = await repo.createCouple('alice');
      await repo.joinByCode('bob', created.code);
      expect(
        () => repo.joinByCode('carol', created.code),
        throwsA(isA<PairingException>().having(
          (e) => e.error, 'error', PairingError.codeNotFound)),
      );
    });
  });

  group('coupleForUser', () {
    test('resolves for both members and is null for a stranger', () async {
      final created = await repo.createCouple('alice');
      await repo.joinByCode('bob', created.code);
      expect((await repo.coupleForUser('alice'))?.isComplete, isTrue);
      expect((await repo.coupleForUser('bob'))?.isComplete, isTrue);
      expect(await repo.coupleForUser('stranger'), isNull);
    });
  });
}
