import 'dart:async';

import 'package:closecall/core/push/push_registration_service.dart';
import 'package:closecall/core/push/single_flight_push_device_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity implements PushDeviceIdentityStore {
  Completer<String> pending = Completer<String>();
  int calls = 0;
  @override
  Future<String> deviceId() {
    calls++;
    return pending.future;
  }
}

void main() {
  test(
    'push and widget credentials share the same in-flight installation ID',
    () async {
      final source = _Identity();
      final store = SingleFlightPushDeviceIdentityStore(source);
      final push = store.deviceId();
      final widget = store.deviceId();
      expect(source.calls, 1);
      source.pending.complete('existing-installation-id');
      expect(await push, 'existing-installation-id');
      expect(await widget, 'existing-installation-id');
      expect(await store.deviceId(), 'existing-installation-id');
      expect(source.calls, 1);
    },
  );

  test(
    'failed identity dependency does not permanently cache the error',
    () async {
      final source = _Identity();
      final store = SingleFlightPushDeviceIdentityStore(source);
      final first = store.deviceId();
      source.pending.completeError(StateError('unavailable'));
      await expectLater(first, throwsStateError);
      source.pending = Completer<String>()..complete('installation');
      expect(await store.deviceId(), 'installation');
      expect(source.calls, 2);
    },
  );
}
