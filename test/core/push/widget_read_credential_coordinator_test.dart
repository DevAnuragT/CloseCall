import 'dart:async';

import 'package:closecall/core/push/push_registration_service.dart';
import 'package:closecall/core/push/widget_read_credential.dart';
import 'package:closecall/core/push/widget_read_credential_api.dart';
import 'package:closecall/core/push/widget_read_credential_coordinator.dart';
import 'package:closecall/core/push/widget_read_credential_store.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

class _Identity implements PushDeviceIdentityStore {
  Object? failure;
  @override
  Future<String> deviceId() async {
    if (failure != null) throw failure!;
    return 'installation';
  }
}

class _Store implements WidgetReadCredentialStore {
  WidgetReadCredential? value;
  Completer<void>? pendingWrite;
  Completer<void>? pendingRead;
  Object? failure;
  final events = <String>[];
  @override
  Future<WidgetReadCredential?> read() async {
    events.add('read');
    if (pendingRead != null) await pendingRead!.future;
    if (failure != null) throw failure!;
    return value;
  }

  @override
  Future<void> write(WidgetReadCredential value) async {
    events.add('write-start');
    if (pendingWrite != null) await pendingWrite!.future;
    if (failure != null) throw failure!;
    this.value = value;
    events.add('write-done');
  }

  @override
  Future<void> delete() async {
    events.add('delete');
    if (failure != null) throw failure!;
    value = null;
  }
}

class _Api implements WidgetReadCredentialApi {
  _Api(this.h);
  final _Harness h;
  int issues = 0;
  final revokes = <String>[];
  Completer<WidgetReadCredential>? pendingIssue;
  Completer<void>? pendingRevoke;
  WidgetReadCredential? response;
  Object? issueFailure;
  Object? revokeFailure;

  @override
  Future<WidgetReadCredential> issueCredential({
    required String deviceId,
  }) async {
    issues++;
    if (issueFailure != null) throw issueFailure!;
    return pendingIssue?.future ??
        response ??
        h.credential(token: 'token-$issues');
  }

  @override
  Future<void> revokeCredential({required String deviceId}) async {
    // The secure record must be gone before any authenticated revocation.
    expect(h.store.value, isNull);
    revokes.add('${h.schedules.pairing.userId}:$deviceId');
    if (revokeFailure != null) throw revokeFailure!;
    if (pendingRevoke != null) await pendingRevoke!.future;
  }
}

class _Harness {
  final schedules = ScheduleHarness();
  final store = _Store();
  final identity = _Identity();
  late final api = _Api(this);
  late WidgetReadCredentialCoordinator coordinator;
  DateTime now = DateTime.utc(2026, 10, 7, 12);

  WidgetReadCredential credential({
    String token = 'stored-token',
    String? user,
    String? couple,
    String device = 'installation',
    Duration remaining = const Duration(hours: 24),
  }) => WidgetReadCredential(
    credential: token,
    userId: user ?? schedules.pairing.userId!,
    coupleId: couple ?? schedules.pairing.couple!.id,
    deviceId: device,
    expiresAt: now.add(remaining),
  );

  Future<void> initialize({bool enabled = true, bool android = true}) async {
    await schedules.initialize();
    schedules.controller.ownTimeline = schedules.controller.ownTimeline!
        .copyWith(autoUpdateEnabled: true);
    if (enabled) await schedules.controller.setAutoSync(true);
    createCoordinator(android: android);
  }

  void createCoordinator({bool android = true}) {
    coordinator = WidgetReadCredentialCoordinator(
      pairing: schedules.pairing,
      schedules: schedules.controller,
      api: api,
      store: store,
      deviceIdentity: identity,
      isAndroid: android,
      now: () => now,
      remoteTimeout: const Duration(milliseconds: 30),
    );
  }

  Future<void> start() async {
    coordinator.start();
    await coordinator.reconcile();
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> repair() async {
    schedules.couples.couple = Couple(
      id: 'repaired',
      memberIds: ['me', 'new-partner'],
    );
    schedules.repository.own = scheduleTimeline(
      couple: 'repaired',
      fallback: null,
    ).copyWith(autoUpdateEnabled: true);
    schedules.repository.partner = scheduleTimeline(
      couple: 'repaired',
      recipient: 'new-partner',
      fallback: null,
    );
    await schedules.pairing.refresh();
    await settle();
    await schedules.controller.setAutoSync(true);
  }

  Future<void> dispose() async {
    coordinator.dispose();
    await schedules.dispose();
  }
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() async => h.dispose());

  test(
    'opt-in issues once and notifications restore instead of rotate',
    () async {
      await h.initialize();
      await h.start();
      expect(h.api.issues, 1);
      expect(h.coordinator.hasCredential, isTrue);
      for (var i = 0; i < 10; i++) {
        h.schedules.controller.resolveNow(sync: false);
      }
      await h.coordinator.reconcile();
      expect(h.api.issues, 1);
      expect(h.store.value!.credential, 'token-1');
    },
  );

  test('local consent off deletes without issuing', () async {
    await h.initialize(enabled: false);
    h.store.value = h.credential();
    await h.start();
    expect(h.api.issues, 0);
    expect(h.store.value, isNull);
  });

  test('remote consent off deletes without issuing', () async {
    await h.initialize();
    h.schedules.controller.ownTimeline = h.schedules.controller.ownTimeline!
        .copyWith(autoUpdateEnabled: false);
    h.store.value = h.credential();
    await h.start();
    expect(h.api.issues, 0);
    expect(h.store.value, isNull);
  });

  test('non-Android deletes even an opted-in stored record', () async {
    await h.initialize(android: false);
    h.store.value = h.credential();
    await h.start();
    expect(h.api.issues, 0);
    expect(h.store.value, isNull);
  });

  test('unvalidated or nonmember pairing cannot issue', () async {
    await h.initialize();
    h.schedules.pairing.couple = Couple(id: 'foreign', memberIds: ['a', 'b']);
    await h.start();
    expect(h.api.issues, 0);
    expect(h.coordinator.hasCredential, isFalse);
  });

  test('restart restores the same secure credential', () async {
    await h.initialize();
    await h.start();
    final stored = h.store.value;
    h.coordinator.dispose();
    h.createCoordinator();
    await h.start();
    expect(h.api.issues, 1);
    expect(h.store.value, same(stored));
    expect(h.coordinator.hasCredential, isTrue);
  });

  test(
    'startup waits for validation without deleting a restart record',
    () async {
      await h.initialize();
      h.store.value = h.credential();
      h.schedules.pairing.initialized = false;
      await h.start();
      expect(h.store.events, isEmpty);
      expect(h.coordinator.hasCredential, isFalse);
      h.schedules.pairing.initialized = true;
      await h.coordinator.reconcile();
      expect(h.coordinator.hasCredential, isTrue);
      expect(h.api.issues, 0);
    },
  );

  test('only less than one hour remaining renews', () async {
    await h.initialize();
    h.store.value = h.credential(remaining: const Duration(hours: 1));
    await h.start();
    expect(h.api.issues, 0);
    h.now = h.now.add(const Duration(seconds: 1));
    await h.coordinator.reconcile();
    expect(h.api.issues, 1);
    expect(h.store.value!.expiresAt, h.now.add(const Duration(hours: 24)));
  });

  test(
    'initial async session restoration does not erase the secure record',
    () async {
      await h.initialize();
      final saved = h.credential();
      h.schedules.pairing.initialized = false;
      h.schedules.auth.change(null);
      h.store.value = saved;
      await h.start();
      expect(h.store.events, isEmpty);
      // PairingController advances authRevision when persisted auth is restored
      // from the initial null identity. This is startup, not a sign-out boundary.
      h.schedules.auth.change('me');
      await h.coordinator.reconcile();
      expect(h.store.value, same(saved));
      expect(h.store.events, isEmpty);
      expect(h.api.issues, 0);
      expect(h.coordinator.hasCredential, isFalse);
    },
  );

  test('expired secure record is replaced, not restored', () async {
    await h.initialize();
    h.store.value = h.credential(remaining: Duration.zero);
    await h.start();
    expect(h.api.issues, 1);
    expect(h.coordinator.hasCredential, isTrue);
  });

  test(
    'background reconciliation does not issue or renew the user session',
    () async {
      await h.initialize();
      h.schedules.controller.setForeground(false);
      await h.start();
      expect(h.api.issues, 0);
      h.schedules.repository.own = h.schedules.repository.own.copyWith(
        autoUpdateEnabled: true,
      );
      h.schedules.controller.setForeground(true);
      await h.settle();
      await h.coordinator.reconcile();
      expect(h.api.issues, 1);
    },
  );

  test('manual photo pauses and deletes read authority', () async {
    await h.initialize();
    await h.start();
    await h.schedules.controller.applyManualPhoto(testPng);
    await h.coordinator.reconcile();
    expect(h.schedules.controller.autoSyncEnabled, isFalse);
    expect(h.store.value, isNull);
    expect(h.coordinator.hasCredential, isFalse);
    expect(h.api.issues, 1);
  });

  test('offline sign-out deletes before best-effort scoped revoke', () async {
    await h.initialize();
    await h.start();
    h.api.revokeFailure = StateError('offline');
    await h.schedules.pairing.signOut();
    await h.coordinator.reconcile();
    expect(h.schedules.pairing.userId, isNull);
    expect(h.store.value, isNull);
    expect(h.api.revokes, ['me:installation']);
  });

  test(
    'late issue after sign-out cannot store or revoke a new auth scope',
    () async {
      await h.initialize();
      h.api.pendingIssue = Completer<WidgetReadCredential>();
      h.coordinator.start();
      final flight = h.coordinator.reconcile();
      await h.settle();
      final old = h.credential();
      final signOut = h.schedules.pairing.signOut();
      h.api.pendingIssue!.complete(old);
      await signOut;
      await flight;
      expect(h.store.value, isNull);
      expect(h.coordinator.hasCredential, isFalse);
      expect(h.api.revokes, ['me:installation']);
      expect(h.store.events, isNot(contains('write-start')));
    },
  );

  test(
    'scope switch cleans old record and issues only for the new scope',
    () async {
      await h.initialize();
      await h.start();
      h.schedules.couples.couple = Couple(
        id: 'new-couple',
        memberIds: ['other', 'partner'],
      );
      h.schedules.repository.own = scheduleTimeline(
        recipient: 'other',
        couple: 'new-couple',
        fallback: null,
      ).copyWith(autoUpdateEnabled: true);
      h.schedules.repository.partner = scheduleTimeline(
        recipient: 'partner',
        couple: 'new-couple',
        fallback: null,
      );
      h.schedules.auth.change('other');
      await h.settle();
      await h.schedules.controller.setAutoSync(true);
      await h.coordinator.reconcile();
      expect(h.store.value!.userId, 'other');
      expect(h.store.value!.coupleId, 'new-couple');
      expect(h.api.revokes, isEmpty);
      expect(h.api.issues, 2);
    },
  );

  test(
    'pause during a late issue stays dirty and discards the result',
    () async {
      await h.initialize();
      h.api.pendingIssue = Completer<WidgetReadCredential>();
      h.coordinator.start();
      final flight = h.coordinator.reconcile();
      await h.settle();
      final old = h.credential();
      await h.schedules.controller.setAutoSync(false);
      h.api.pendingIssue!.complete(old);
      await flight;
      expect(h.store.value, isNull);
      expect(h.coordinator.hasCredential, isFalse);
      expect(h.store.events, isNot(contains('write-start')));
    },
  );

  test('late secure write is deleted after a manual pause', () async {
    await h.initialize();
    h.store.pendingWrite = Completer<void>();
    h.coordinator.start();
    final flight = h.coordinator.reconcile();
    await h.settle();
    expect(h.store.events, contains('write-start'));
    await h.schedules.controller.applyManualPhoto(testPng);
    h.store.pendingWrite!.complete();
    await flight;
    expect(h.store.value, isNull);
    expect(
      h.store.events.indexOf('write-done'),
      lessThan(h.store.events.lastIndexOf('delete')),
    );
  });

  test('late secure write is deleted before sign-out completes', () async {
    await h.initialize();
    h.store.pendingWrite = Completer<void>();
    h.coordinator.start();
    final flight = h.coordinator.reconcile();
    await h.settle();
    final signOut = h.schedules.pairing.signOut();
    h.store.pendingWrite!.complete();
    await signOut;
    await flight;
    expect(h.store.value, isNull);
    expect(h.coordinator.hasCredential, isFalse);
  });

  test(
    'late issue during re-pair never writes the old couple credential',
    () async {
      await h.initialize();
      final issue = Completer<WidgetReadCredential>();
      h.api.pendingIssue = issue;
      final old = h.credential();
      h.coordinator.start();
      final flight = h.coordinator.reconcile();
      await h.settle();
      await h.repair();
      h.api.pendingIssue = null;
      issue.complete(old);
      await flight;
      expect(h.api.issues, 2);
      expect(h.store.value!.coupleId, 'repaired');
      expect(h.api.revokes, isEmpty);
      expect(
        h.store.events.where((event) => event == 'write-start'),
        hasLength(1),
      );
    },
  );

  test(
    'late write during re-pair is deleted before the new record writes',
    () async {
      await h.initialize();
      h.store.pendingWrite = Completer<void>();
      h.coordinator.start();
      final flight = h.coordinator.reconcile();
      await h.settle();
      await h.repair();
      h.store.pendingWrite!.complete();
      await flight;
      expect(h.store.value!.coupleId, 'repaired');
      expect(h.api.issues, 2);
      final firstWrite = h.store.events.indexOf('write-done');
      final cleanup = h.store.events.indexOf('delete', firstWrite + 1);
      final newWrite = h.store.events.lastIndexOf('write-start');
      expect(firstWrite, lessThan(cleanup));
      expect(cleanup, lessThan(newWrite));
    },
  );

  test(
    'brief pause during a read cannot restore the pre-pause token',
    () async {
      await h.initialize();
      h.store.value = h.credential();
      h.store.pendingRead = Completer<void>();
      h.coordinator.start();
      final flight = h.coordinator.reconcile();
      await h.settle();
      await h.schedules.controller.setAutoSync(false);
      await h.schedules.controller.setAutoSync(true);
      h.store.pendingRead!.complete();
      await flight;
      expect(h.api.issues, 1);
      expect(h.store.value!.credential, 'token-1');
    },
  );

  test('broken secure channel cannot indefinitely block sign-out', () async {
    await h.initialize();
    h.store.pendingWrite = Completer<void>();
    h.coordinator.start();
    final flight = h.coordinator.reconcile();
    await h.settle();
    await h.schedules.pairing.signOut();
    expect(h.schedules.pairing.userId, isNull);
    expect(h.coordinator.hasCredential, isFalse);
    h.store.pendingWrite!.complete();
    await flight;
    await h.settle();
    expect(h.store.value, isNull);
    expect(h.api.revokes, isEmpty);
  });

  test('late read cannot restore a signed-out credential', () async {
    await h.initialize();
    h.store.value = h.credential();
    h.store.pendingRead = Completer<void>();
    h.coordinator.start();
    final flight = h.coordinator.reconcile();
    await h.settle();
    h.schedules.auth.change(null);
    h.store.pendingRead!.complete();
    await flight;
    expect(h.store.value, isNull);
    expect(h.api.issues, 0);
  });

  test(
    'uncertain issue is never automatically replayed or adopted late',
    () async {
      await h.initialize();
      h.api.pendingIssue = Completer<WidgetReadCredential>();
      final old = h.credential();
      await h.start(); // Bounded timeout.
      await h.coordinator.reconcile();
      h.api.pendingIssue!.complete(old);
      await h.settle();
      await h.coordinator.reconcile();
      expect(h.api.issues, 1);
      expect(h.store.value, isNull);
      expect(h.coordinator.hasCredential, isFalse);
    },
  );

  test(
    'timed-out old revoke fences issuance after same-user sign-in',
    () async {
      await h.initialize();
      await h.start();
      h.api.pendingRevoke = Completer<void>();
      await h.schedules.pairing.signOut();
      expect(h.schedules.pairing.userId, isNull);
      h.schedules.auth.change('me');
      await h.settle();
      h.schedules.controller.ownTimeline = h.schedules.controller.ownTimeline!
          .copyWith(autoUpdateEnabled: true);
      await h.schedules.controller.setAutoSync(true);
      await h.coordinator.reconcile();
      expect(h.api.issues, 1);
      h.api.pendingRevoke!.complete();
      await h.settle();
      await h.coordinator.reconcile();
      expect(h.api.issues, 2);
      expect(h.coordinator.hasCredential, isTrue);
      expect(h.api.revokes, ['me:installation']);
    },
  );

  test('storage failure is nonblocking and prevents issuance', () async {
    await h.initialize();
    h.store.failure = StateError('secure storage unavailable');
    await h.start();
    await h.coordinator.reconcile();
    expect(h.api.issues, 0);
    expect(h.coordinator.hasCredential, isFalse);
    await h.schedules.pairing.signOut();
    expect(h.schedules.pairing.userId, isNull);
  });

  test('failed old revoke remains fenced across a same-user sign-in', () async {
    await h.initialize();
    await h.start();
    h.api.revokeFailure = StateError('uncertain transport failure');
    await h.schedules.pairing.signOut();
    h.schedules.auth.change('me');
    await h.settle();
    h.schedules.controller.ownTimeline = h.schedules.controller.ownTimeline!
        .copyWith(autoUpdateEnabled: true);
    await h.schedules.controller.setAutoSync(true);
    await h.coordinator.reconcile();
    expect(h.api.issues, 1);
    expect(h.coordinator.hasCredential, isFalse);
    expect(h.store.value, isNull);
  });

  test(
    'device identity failure is nonblocking and prevents issuance',
    () async {
      await h.initialize();
      h.identity.failure = StateError('identity unavailable');
      await h.start();
      expect(h.api.issues, 0);
      expect(h.coordinator.hasCredential, isFalse);
    },
  );

  for (final invalid in [
    'user',
    'couple',
    'device',
    'expired',
    'far-future',
    'empty',
  ]) {
    test(
      'invalid issue response $invalid fails closed without replay',
      () async {
        await h.initialize();
        h.api.response = h.credential(
          user: invalid == 'user' ? 'wrong' : null,
          couple: invalid == 'couple' ? 'wrong' : null,
          device: invalid == 'device' ? 'wrong' : 'installation',
          token: invalid == 'empty' ? '' : 'opaque-token',
          remaining: invalid == 'expired'
              ? Duration.zero
              : invalid == 'far-future'
              ? const Duration(days: 2)
              : const Duration(hours: 24),
        );
        await h.start();
        await h.coordinator.reconcile();
        expect(h.api.issues, 1);
        expect(h.store.value, isNull);
        expect(h.coordinator.hasCredential, isFalse);
      },
    );
  }
}
