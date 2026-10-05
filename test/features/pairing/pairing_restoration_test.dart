import 'dart:async';

import 'package:closecall/features/auth/data/auth_session.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

class _CountingAuth extends FakeAuth {
  int initializations = 0;
  Object? initializationFailure;
  Completer<void>? pending;
  @override
  Future<void> initialize() async {
    initializations++;
    if (initializationFailure != null) throw initializationFailure!;
    if (pending != null) await pending!.future;
  }
}

class _Couples extends FakeCouples {
  Object? failure;
  Completer<Couple?>? pending;
  int reads = 0;
  @override
  Future<Couple?> coupleForUser(String id) async {
    reads++;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return super.coupleForUser(id);
  }
}

void main() {
  test(
    'failed revalidation cannot leave cached identity authorized in the gate',
    () async {
      final auth = _CountingAuth()..change('me');
      final pairing = PairingController(session: auth, repository: _Couples());
      await pairing.initialize();
      expect(pairing.initialized, isTrue);
      auth.initializationFailure = const SessionValidationException();
      await pairing.initialize();
      expect(pairing.initialized, isFalse);
      expect(auth.userId, 'me');
      expect(pairing.error, isNotNull);
      pairing.dispose();
      auth.dispose();
    },
  );

  test(
    'pairing failure leaves auth initialized; retry does not reinitialize auth',
    () async {
      final auth = _CountingAuth()..change('me');
      final repository = _Couples()
        ..failure = StateError('Synthetic offline error');
      final pairing = PairingController(session: auth, repository: repository);
      await pairing.initialize();
      expect(pairing.initialized, isTrue);
      expect(pairing.hasLoadedPairing, isFalse);
      expect(pairing.error, isNotNull);
      repository.failure = null;
      await pairing.retry();
      expect(auth.initializations, 1);
      expect(pairing.hasLoadedPairing, isTrue);
      expect(pairing.error, isNull);
      pairing.dispose();
      auth.dispose();
    },
  );

  test(
    'disposed initialization cannot mark auth initialized or read pairing',
    () async {
      final auth = _CountingAuth()..pending = Completer<void>();
      final repository = _Couples();
      final pairing = PairingController(session: auth, repository: repository);
      final flight = pairing.initialize();
      pairing.dispose();
      auth.pending!.complete();
      await flight;
      expect(pairing.initialized, isFalse);
      expect(repository.reads, 0);
      auth.dispose();
    },
  );

  test(
    'account switch discards old pairing and loads only the current scope',
    () async {
      final auth = _CountingAuth()..change('old');
      final repository = _Couples()..pending = Completer<Couple?>();
      final pairing = PairingController(session: auth, repository: repository);
      final flight = pairing.initialize();
      await Future<void>.delayed(Duration.zero);
      final oldRead = repository.pending!;
      auth.change('new');
      repository.pending = null;
      repository.couple = Couple(id: 'new-scope', memberIds: ['new']);
      oldRead.complete(Couple(id: 'old-scope', memberIds: ['old']));
      await flight;
      await Future<void>.delayed(Duration.zero);
      expect(pairing.couple?.id, 'new-scope');
      expect(pairing.authRevision, 1);
      pairing.dispose();
      auth.dispose();
    },
  );
}
