import 'dart:math';

import 'package:closecall/features/pairing/domain/pairing_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generate', () {
    test('produces a code of the canonical length from the charset', () {
      final code = PairingCode.generate(random: Random(42));
      expect(code.length, PairingCode.length);
      expect(code.split('').every(PairingCode.charset.contains), isTrue);
    });

    test('is deterministic for a seeded Random', () {
      expect(
        PairingCode.generate(random: Random(1)),
        PairingCode.generate(random: Random(1)),
      );
    });

    test('never emits ambiguous characters', () {
      for (final seed in [0, 1, 7, 99, 1234]) {
        final code = PairingCode.generate(random: Random(seed));
        for (final bad in ['0', 'O', '1', 'I', 'L']) {
          expect(code.contains(bad), isFalse, reason: 'seed $seed had $bad');
        }
      }
    });
  });

  group('normalize', () {
    test('uppercases and strips spaces and hyphens', () {
      expect(PairingCode.normalize(' abc-def '), 'ABCDEF');
      expect(PairingCode.normalize('a b c d e f'), 'ABCDEF');
    });
  });

  group('isValid', () {
    test('accepts a freshly generated code', () {
      final code = PairingCode.generate(random: Random(5));
      expect(PairingCode.isValid(code), isTrue);
      expect(PairingCode.isValid(PairingCode.format(code)), isTrue);
    });

    test('rejects wrong length', () {
      expect(PairingCode.isValid('ABC'), isFalse);
      expect(PairingCode.isValid('ABCDEFG'), isFalse);
    });

    test('rejects ambiguous / out-of-charset characters', () {
      expect(PairingCode.isValid('ABC0EF'), isFalse); // 0 excluded
      expect(PairingCode.isValid('ABCOEF'), isFalse); // O excluded
      expect(PairingCode.isValid('ABC1EF'), isFalse); // 1 excluded
    });
  });

  group('format', () {
    test('groups a canonical code as ABC-DEF', () {
      expect(PairingCode.format('ABCDEF'), 'ABC-DEF');
      expect(PairingCode.format('abc def'), 'ABC-DEF');
    });

    test('leaves non-canonical input ungrouped', () {
      expect(PairingCode.format('ABC'), 'ABC');
    });
  });
}
