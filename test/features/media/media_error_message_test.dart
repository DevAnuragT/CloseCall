import 'dart:async';

import 'package:closecall/features/media/data/media_repository.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'network and timeout errors explain uncertain upload and explicit recovery',
    () {
      for (final failure in [
        const ServerpodClientNetworkException(
          'Request timed out. secret URL/token',
        ),
        TimeoutException('private endpoint and request ID'),
      ]) {
        final message = mediaErrorMessage(failure);
        expect(message, contains('may have succeeded'));
        expect(message, contains('Retry the same upload'));
        expect(message, contains('refresh'));
        expect(message, isNot(contains('secret')));
        expect(message, isNot(contains('private endpoint')));
      }
    },
  );

  test('unknown typed codes and foreign exception text never reach UI', () {
    const secret = 'https://private.invalid/asset?Authorization=hidden-id';
    for (final failure in [
      MediaFailure(code: secret),
      const FormatException(secret, secret),
      StateError(secret),
      Exception(secret),
      ServerpodClientBadRequest(secret),
    ]) {
      final message = mediaErrorMessage(failure);
      expect(message, isNot(contains('private.invalid')));
      expect(message, isNot(contains('Authorization')));
      expect(message, isNot(contains('hidden-id')));
    }
  });

  test('known local validation and pending-upload guidance remains useful', () {
    expect(
      mediaErrorMessage(const FormatException('Photo must be a valid PNG.')),
      contains('2 MiB'),
    );
    expect(
      mediaErrorMessage(
        StateError(
          'Retry or cancel the pending upload before choosing another photo.',
        ),
      ),
      'Retry or cancel the pending upload before choosing another photo.',
    );
  });
}
