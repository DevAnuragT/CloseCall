import 'package:closecall_server/src/auth/authentication.dart';
import 'package:closecall_server/src/pairing/invite_code.dart';
import 'package:test/test.dart';

void main() {
  test('normalization matches the Flutter pairing code contract', () {
    expect(InviteCode.normalize(' ab2-cd3 \n'), 'AB2CD3');
    expect(InviteCode.isValid('AB2CD3'), isTrue);
    for (final code in [
      'ABOCD3',
      'ABICD3',
      'ABLCD3',
      'AB1CD3',
      'AB0CD3',
      'ABCDE',
    ]) {
      expect(InviteCode.isValid(code), isFalse, reason: code);
    }
  });

  test('generated codes use the six-character app alphabet', () {
    for (var i = 0; i < 100; i++) {
      expect(InviteCode.isValid(InviteCode.generate()), isTrue);
    }
  });

  test('anonymous creation fails closed outside development and test', () {
    requireDevelopmentAuthentication('development');
    requireDevelopmentAuthentication('test');
    for (final mode in ['staging', 'production', 'unknown', '']) {
      expect(() => requireDevelopmentAuthentication(mode), throwsStateError);
    }
  });
}
