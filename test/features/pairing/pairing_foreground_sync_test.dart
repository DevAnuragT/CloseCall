import 'dart:async';

import 'package:closecall/app/app_shell.dart';
import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

final _cleanups = <FutureOr<void> Function()>[];

// Cancel timers before testWidgets checks its pending-timer invariant (the
// package:test addTearDown hook runs after that check).
void _syncTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    _cleanups.clear();
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final cleanup in _cleanups.reversed) {
        await cleanup();
      }
      _cleanups.clear();
    }
  });
}

class _Auth extends FakeAuth {
  int initializations = 0;
  Completer<void>? pendingInitialization;

  @override
  Future<void> initialize() async {
    initializations++;
    if (pendingInitialization != null) await pendingInitialization!.future;
  }
}

// Each phone gets its own repository/session but reads the same persisted state.
class _PersistedPairing {
  Couple? couple;
  String? code;
}

class _Repository implements CoupleRepository, PairingCodeReader {
  _Repository(this.persisted);
  final _PersistedPairing persisted;
  int reads = 0;
  int creates = 0;
  int joins = 0;
  int activeReads = 0;
  int maxActiveReads = 0;
  Object? readFailure;
  Object? mutationFailure;
  Completer<Couple?>? pendingRead;
  Completer<PairingResult>? pendingCreate;
  Completer<Couple>? pendingJoin;
  @override
  String? currentInviteCode;

  @override
  Future<Couple?> coupleForUser(String userId) async {
    reads++;
    activeReads++;
    if (activeReads > maxActiveReads) maxActiveReads = activeReads;
    final snapshot = persisted.couple;
    final code = persisted.code;
    try {
      if (readFailure != null) throw readFailure!;
      final result = pendingRead == null ? snapshot : await pendingRead!.future;
      if (result == null || !result.memberIds.contains(userId)) {
        currentInviteCode = null;
        return null;
      }
      currentInviteCode = code;
      // RPC deserialization returns equal but distinct instances.
      return result.copyWith(memberIds: List.of(result.memberIds));
    } finally {
      activeReads--;
    }
  }

  @override
  Future<PairingResult> createCouple(String userId) async {
    creates++;
    if (mutationFailure != null) throw mutationFailure!;
    final result = pendingCreate == null
        ? PairingResult(
            couple: Couple(id: 'couple', memberIds: [userId]),
            code: 'ABC123',
          )
        : await pendingCreate!.future;
    persisted.couple = result.couple;
    persisted.code = currentInviteCode = result.code;
    return result;
  }

  @override
  Future<Couple> joinByCode(String userId, String code) async {
    joins++;
    if (mutationFailure != null) throw mutationFailure!;
    final result = pendingJoin == null
        ? persisted.couple!.copyWith(
            memberIds: [...persisted.couple!.memberIds, userId],
          )
        : await pendingJoin!.future;
    persisted.couple = result;
    persisted.code = currentInviteCode = null;
    return result;
  }
}

class _Phone {
  _Phone(_PersistedPairing persisted, {String? identity = 'me'}) {
    auth.change(identity);
    repository = _Repository(persisted);
    pairing = PairingController(session: auth, repository: repository);
    _cleanups.add(dispose);
  }
  final auth = _Auth();
  late final _Repository repository;
  late final PairingController pairing;
  bool _disposed = false;

  Future<void> start({bool foreground = true}) async {
    pairing.enableForegroundSync(foreground: foreground);
    await pairing.initialize();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pairing.dispose();
    auth.dispose();
  }
}

void main() {
  _syncTest('two open phones observe a partner join without reopening', (
    tester,
  ) async {
    final persisted = _PersistedPairing();
    final inviter = _Phone(persisted);
    final partner = _Phone(persisted, identity: 'partner');
    await inviter.start();
    await partner.start();
    await inviter.pairing.createInvite();
    expect(inviter.pairing.couple?.isComplete, isFalse);
    expect(inviter.pairing.inviteCode, 'ABC123');
    await partner.pairing.join('ABC123');
    expect(inviter.pairing.couple?.isComplete, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(inviter.pairing.couple?.memberIds, ['me', 'partner']);
    expect(inviter.pairing.inviteCode, isNull);
    expect(inviter.auth.initializations, 1);
    expect(inviter.repository.creates, 1);
    expect(inviter.repository.joins, 0);
    expect(partner.repository.creates, 0);
    expect(partner.repository.joins, 1);
    final reads = inviter.repository.reads;
    await tester.pump(const Duration(seconds: 14));
    expect(inviter.repository.reads, reads);
    await tester.pump(const Duration(seconds: 1));
    expect(inviter.repository.reads, reads + 1);
  });

  _syncTest('unpaired and remotely removed pairing are detected', (
    tester,
  ) async {
    final persisted = _PersistedPairing();
    final phone = _Phone(persisted);
    await phone.start();
    expect(phone.pairing.couple, isNull);
    persisted.couple = Couple(id: 'remote', memberIds: ['me', 'partner']);
    await tester.pump(const Duration(seconds: 5));
    expect(phone.pairing.couple?.isComplete, isTrue);
    persisted.couple = null;
    await tester.pump(const Duration(seconds: 15));
    expect(phone.pairing.couple, isNull);
    expect(phone.pairing.hasLoadedPairing, isTrue);
    expect(phone.pairing.inviteCode, isNull);
    expect(phone.repository.creates + phone.repository.joins, 0);
  });

  _syncTest('pending-to-complete updates existing schedule/media consumers', (
    tester,
  ) async {
    final harness = ScheduleHarness();
    harness.couples.couple = Couple(id: 'couple', memberIds: ['me']);
    await harness.initialize();
    _cleanups.add(harness.dispose);
    harness.pairing.enableForegroundSync();
    await tester.pump();
    expect(harness.controller.canSchedule, isFalse);
    expect(harness.media.canShare, isFalse);
    harness.couples.couple = Couple(id: 'couple', memberIds: ['me', 'partner']);
    await tester.pump(const Duration(seconds: 5));
    expect(harness.controller.canSchedule, isTrue);
    expect(harness.media.canShare, isTrue);
    expect(harness.repository.watches, 1);
    expect(harness.photos.downloads, contains('asset'));
    final downloads = harness.photos.downloads.length;
    final nativeEvents = harness.events.length;
    var notifications = 0;
    harness.pairing.addListener(() => notifications++);
    harness.couples.couple = harness.couples.couple!.copyWith();
    await tester.pump(const Duration(seconds: 15));
    expect(notifications, 0);
    expect(harness.photos.downloads.length, downloads);
    expect(harness.events.length, nativeEvents);
    expect(harness.repository.watches, 1);
  });

  _syncTest('foreground opt-in is disabled by default for demo/fake use', (
    tester,
  ) async {
    final phone = _Phone(_PersistedPairing());
    await phone.pairing.initialize();
    phone.pairing.setForeground(true);
    await tester.pump(const Duration(minutes: 5));
    expect(phone.repository.reads, 1);
  });

  _syncTest(
    'equal couple/invite snapshots are quiet; an invite change notifies',
    (tester) async {
      final persisted = _PersistedPairing()
        ..couple = Couple(id: 'couple', memberIds: ['me'])
        ..code = 'ABC123';
      final phone = _Phone(persisted);
      await phone.start();
      final snapshot = phone.pairing.couple;
      var notifications = 0;
      phone.pairing.addListener(() => notifications++);
      await tester.pump(const Duration(seconds: 5));
      expect(notifications, 0);
      expect(phone.pairing.couple, same(snapshot));
      expect(phone.pairing.inviteCode, 'ABC123');
      persisted.code = 'NEW123';
      await tester.pump(const Duration(seconds: 5));
      expect(notifications, 1);
      expect(phone.pairing.couple, same(snapshot));
      expect(phone.pairing.inviteCode, 'NEW123');
      await tester.pump(const Duration(seconds: 5));
      expect(notifications, 1);
    },
  );

  _syncTest('paused has no queries; resume immediately reads once', (
    tester,
  ) async {
    final persisted = _PersistedPairing();
    final phone = _Phone(persisted);
    await phone.start(foreground: false);
    await tester.pump(const Duration(minutes: 2));
    expect(phone.repository.reads, 1);
    persisted.couple = Couple(id: 'remote', memberIds: ['me', 'partner']);
    phone.pairing.setForeground(true);
    await tester.pump();
    expect(phone.repository.reads, 2);
    expect(phone.pairing.couple?.isComplete, isTrue);
    phone.pairing.setForeground(false);
    await tester.pump(const Duration(minutes: 2));
    expect(phone.repository.reads, 2);
    phone.pairing.setForeground(true);
    phone.pairing.setForeground(true);
    await tester.pump();
    expect(phone.repository.reads, 3);
    expect(phone.auth.initializations, 1);
  });

  _syncTest('no overlapping reads, including explicit refresh on resume', (
    tester,
  ) async {
    final phone = _Phone(_PersistedPairing());
    await phone.start();
    final pending = phone.repository.pendingRead = Completer<Couple?>();
    await tester.pump(const Duration(seconds: 5));
    expect(phone.repository.reads, 2);
    expect(phone.pairing.busy, isFalse);
    await tester.pump(const Duration(minutes: 5));
    expect(phone.repository.reads, 2);
    phone.pairing.setForeground(false);
    phone.pairing.setForeground(true);
    final refresh = phone.pairing.refresh();
    await tester.pump();
    expect(phone.repository.reads, 2);
    phone.repository.pendingRead = null;
    pending.complete(null);
    await refresh;
    await tester.pump();
    expect(phone.repository.maxActiveReads, 1);
    expect(phone.pairing.error, isNull);
    expect(phone.pairing.busy, isFalse);
  });

  _syncTest('account switch drops a late poll and loads the new scope', (
    tester,
  ) async {
    final persisted = _PersistedPairing()
      ..couple = Couple(id: 'old', memberIds: ['me', 'partner']);
    final phone = _Phone(persisted);
    await phone.start();
    final pending = phone.repository.pendingRead = Completer<Couple?>();
    await tester.pump(const Duration(seconds: 15));
    phone.auth.change('new');
    expect(phone.pairing.couple, isNull);
    expect(phone.pairing.hasLoadedPairing, isFalse);
    phone.repository.pendingRead = null;
    persisted.couple = Couple(id: 'new', memberIds: ['new']);
    persisted.code = 'NEW123';
    pending.complete(Couple(id: 'old', memberIds: ['me', 'partner']));
    await tester.pump();
    expect(phone.pairing.couple?.id, 'new');
    expect(phone.pairing.inviteCode, 'NEW123');
    expect(phone.repository.maxActiveReads, 1);
    expect(phone.auth.initializations, 1);
    expect(phone.pairing.authRevision, 1);
  });

  _syncTest('token refresh of the same identity does not reinitialize auth', (
    tester,
  ) async {
    final phone = _Phone(_PersistedPairing());
    await phone.start();
    var notifications = 0;
    phone.pairing.addListener(() => notifications++);
    phone.auth.change('me');
    await tester.pump();
    expect(phone.repository.reads, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(phone.repository.reads, 2);
    expect(phone.auth.initializations, 1);
    expect(phone.pairing.authRevision, 0);
    expect(notifications, 0);
  });

  for (final create in [true, false]) {
    _syncTest(
      '${create ? 'create' : 'join'} is protected from a late quiet poll',
      (tester) async {
        final persisted = _PersistedPairing();
        final phone = _Phone(persisted);
        await phone.start();
        final pending = phone.repository.pendingRead = Completer<Couple?>();
        await tester.pump(const Duration(seconds: 5));
        if (!create) {
          persisted.couple = Couple(id: 'couple', memberIds: ['partner']);
          persisted.code = 'ABC123';
        }
        if (create) {
          await phone.pairing.createInvite();
        } else {
          await phone.pairing.join('ABC123');
        }
        final result = phone.pairing.couple;
        final code = phone.pairing.inviteCode;
        pending.complete(null);
        phone.repository.pendingRead = null;
        await tester.pump();
        expect(phone.pairing.couple, same(result));
        expect(phone.pairing.inviteCode, code);
        expect(phone.pairing.hasLoadedPairing, isTrue);
        expect(phone.pairing.error, isNull);
        expect(phone.repository.creates, create ? 1 : 0);
        expect(phone.repository.joins, create ? 0 : 1);
      },
    );
  }

  _syncTest('quiet poll cannot erase a mutation error or its retry', (
    tester,
  ) async {
    final persisted = _PersistedPairing();
    final phone = _Phone(persisted);
    await phone.start();
    final pending = phone.repository.pendingRead = Completer<Couple?>();
    await tester.pump(const Duration(seconds: 5));
    final failure = phone.repository.mutationFailure = const PairingException(
      PairingError.codeNotFound,
    );
    await phone.pairing.join('BAD123');
    phone.repository.pendingRead = null;
    pending.complete(null);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(phone.pairing.error, same(failure));
    expect(phone.repository.reads, 2);
    persisted.couple = Couple(id: 'couple', memberIds: ['partner']);
    phone.repository.mutationFailure = null;
    await phone.pairing.retry();
    expect(phone.repository.joins, 2);
    expect(phone.pairing.error, isNull);
    expect(phone.pairing.couple?.isComplete, isTrue);
  });

  for (final create in [true, false]) {
    _syncTest('poll pauses during in-flight ${create ? 'create' : 'join'}', (
      tester,
    ) async {
      final phone = _Phone(_PersistedPairing());
      await phone.start();
      final pendingCreate = phone.repository.pendingCreate =
          Completer<PairingResult>();
      final pendingJoin = phone.repository.pendingJoin = Completer<Couple>();
      final operation = create
          ? phone.pairing.createInvite()
          : phone.pairing.join('ABC123');
      await tester.pump(const Duration(minutes: 5));
      expect(phone.repository.reads, 1);
      expect(phone.pairing.busy, isTrue);
      if (create) {
        pendingCreate.complete(
          PairingResult(
            couple: Couple(id: 'couple', memberIds: ['me']),
            code: 'ABC123',
          ),
        );
      } else {
        pendingJoin.complete(
          Couple(id: 'couple', memberIds: ['partner', 'me']),
        );
      }
      await operation;
      await tester.pump(Duration(seconds: create ? 5 : 15));
      expect(phone.repository.reads, 2);
    });
  }

  _syncTest('account switch also drops explicit mutation success and error', (
    tester,
  ) async {
    for (final fails in [false, true]) {
      final phone = _Phone(_PersistedPairing());
      await phone.start();
      final pending = phone.repository.pendingCreate =
          Completer<PairingResult>();
      final operation = phone.pairing.createInvite();
      phone.auth.change('new');
      if (fails) {
        pending.completeError(StateError('Late old-account failure'));
      } else {
        pending.complete(
          PairingResult(
            couple: Couple(id: 'old', memberIds: ['me']),
            code: 'OLD123',
          ),
        );
      }
      await operation;
      await tester.pump();
      expect(phone.pairing.couple, isNull);
      expect(phone.pairing.inviteCode, isNull);
      expect(phone.pairing.error, isNull);
      expect(phone.pairing.hasLoadedPairing, isTrue);
      phone.dispose();
    }
  });

  _syncTest('transient offline keeps shell/tab and quietly backs off/retries', (
    tester,
  ) async {
    final persisted = _PersistedPairing()
      ..couple = Couple(id: 'couple', memberIds: ['me', 'partner']);
    final phone = _Phone(persisted);
    await phone.start();
    await tester.pumpWidget(
      MaterialApp(home: AppShell(pairing: phone.pairing)),
    );
    await tester.tap(find.text('Moments'));
    await tester.pumpAndSettle();
    final snapshot = phone.pairing.couple;
    var notifications = 0;
    phone.pairing.addListener(() => notifications++);
    phone.repository.readFailure = StateError('Synthetic offline');
    await tester.pump(const Duration(seconds: 15));
    expect(phone.repository.reads, 2);
    await tester.pump(const Duration(seconds: 29));
    expect(phone.repository.reads, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(phone.repository.reads, 3);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 60));
    }
    expect(phone.repository.reads, 11);
    expect(phone.pairing.couple, same(snapshot));
    expect(phone.pairing.error, isNull);
    expect(phone.pairing.busy, isFalse);
    expect(notifications, 0);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    phone.repository.readFailure = null;
    persisted.couple = null;
    await tester.pump(const Duration(seconds: 60));
    expect(phone.pairing.couple, isNull);
    expect(notifications, 1);
    final reads = phone.repository.reads;
    await tester.pump(const Duration(seconds: 5));
    expect(phone.repository.reads, reads + 1);
    expect(phone.auth.initializations, 1);
  });

  _syncTest('fresh read retries are bounded; a loaded read can heal', (
    tester,
  ) async {
    final phone = _Phone(_PersistedPairing());
    phone.repository.readFailure = StateError('Synthetic offline');
    final starting = phone.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await starting;
    await tester.pump(const Duration(minutes: 5));
    expect(phone.repository.reads, 3);
    expect(phone.pairing.hasLoadedPairing, isFalse);
    expect(phone.pairing.error, isNotNull);
    phone.repository.readFailure = null;
    await phone.pairing.retry();
    expect(phone.pairing.error, isNull);
    expect(phone.pairing.hasLoadedPairing, isTrue);
    phone.repository.readFailure = StateError('Synthetic read failure');
    final refreshing = phone.pairing.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await refreshing;
    expect(phone.pairing.error, isNotNull);
    phone.repository.readFailure = null;
    await tester.pump(const Duration(seconds: 5));
    expect(phone.pairing.error, isNull);
    final reads = phone.repository.reads;
    await phone.pairing.retry();
    expect(phone.repository.reads, reads);
    expect(phone.auth.initializations, 1);
  });

  _syncTest(
    'pause discards late poll; resume waits then immediately refreshes',
    (tester) async {
      final persisted = _PersistedPairing();
      final phone = _Phone(persisted);
      await phone.start();
      final pending = phone.repository.pendingRead = Completer<Couple?>();
      await tester.pump(const Duration(seconds: 5));
      phone.pairing.setForeground(false);
      phone.repository.pendingRead = null;
      pending.complete(Couple(id: 'stale', memberIds: ['me', 'partner']));
      await tester.pump();
      expect(phone.pairing.couple, isNull);
      await tester.pump(const Duration(minutes: 2));
      expect(phone.repository.reads, 2);
      phone.pairing.setForeground(true);
      await tester.pump();
      final second = phone.repository.pendingRead = Completer<Couple?>();
      await tester.pump(const Duration(seconds: 5));
      phone.pairing.setForeground(false);
      phone.pairing.setForeground(true);
      await tester.pump();
      expect(phone.repository.reads, 4);
      persisted.couple = Couple(id: 'fresh', memberIds: ['me']);
      phone.repository.pendingRead = null;
      second.complete(null);
      await tester.pump();
      await tester.pump();
      expect(phone.pairing.couple?.id, 'fresh');
      expect(phone.repository.maxActiveReads, 1);
    },
  );

  _syncTest('sign-out stops timers; dispose drops late success/failure', (
    tester,
  ) async {
    final signedOut = _Phone(_PersistedPairing());
    await signedOut.start();
    signedOut.auth.change(null);
    await tester.pump(const Duration(minutes: 5));
    expect(signedOut.repository.reads, 1);
    expect(signedOut.pairing.couple, isNull);
    signedOut.dispose();
    for (final failure in [false, true]) {
      final phone = _Phone(_PersistedPairing());
      await phone.start();
      final pending = phone.repository.pendingRead = Completer<Couple?>();
      await tester.pump(const Duration(seconds: 5));
      var notifications = 0;
      phone.pairing.addListener(() => notifications++);
      phone.dispose();
      if (failure) {
        pending.completeError(StateError('Late synthetic failure'));
      } else {
        pending.complete(Couple(id: 'late', memberIds: ['me', 'partner']));
      }
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));
      expect(phone.repository.reads, 2);
      expect(phone.pairing.couple, isNull);
      expect(phone.pairing.error, isNull);
      expect(notifications, 0);
    }
  });

  _syncTest('late auth initialization cannot authorize a switched account', (
    tester,
  ) async {
    final phone = _Phone(_PersistedPairing());
    final pending = phone.auth.pendingInitialization = Completer<void>();
    final initialization = phone.start();
    phone.auth.change('new');
    pending.complete();
    await initialization;
    await tester.pump(const Duration(minutes: 1));
    expect(phone.pairing.initialized, isFalse);
    expect(phone.repository.reads, 0);
  });
}
