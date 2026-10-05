import 'dart:async';

import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:closecall/core/permissions/widget_readiness_controller.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/live_fakes.dart';

class FakePermissions implements WidgetPermissionService {
  NotificationAccess access = NotificationAccess.denied;
  NotificationAccess requestResult = NotificationAccess.denied;
  bool installed = false;
  bool pin = true;
  bool settings = true;
  Object? failure;
  Object? requestFailure;
  Completer<NotificationAccess>? statusGate;
  Completer<NotificationAccess>? requestGate;
  Completer<bool>? widgetGate;
  final events = <String>[];
  int active = 0;
  int maxActive = 0;
  Future<T> _call<T>(String name, Future<T> Function() action) async {
    events.add(name);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await action();
    } finally {
      active--;
    }
  }

  @override
  Future<NotificationAccess> notificationStatus() => _call('status', () async {
    if (failure != null) throw failure!;
    final gate = statusGate;
    statusGate = null;
    return gate == null ? access : await gate.future;
  });

  @override
  Future<NotificationAccess> requestNotifications() =>
      _call('request', () async {
        if (requestFailure != null) throw requestFailure!;
        return requestGate == null ? requestResult : await requestGate!.future;
      });

  @override
  Future<bool> hasInstalledWidget() => _call('installed', () async {
    final gate = widgetGate;
    widgetGate = null;
    return gate == null ? installed : await gate.future;
  });

  @override
  Future<bool> canPinWidget() => _call('pinSupport', () async => pin);

  @override
  Future<void> requestPinWidget() => _call('pin', () async {});

  @override
  Future<bool> openSettings() => _call('settings', () async => settings);
}

class FailingPromptStore implements PermissionPromptStore {
  @override
  Future<bool> wasHandled() async => throw StateError('private-token');
  @override
  Future<void> markHandled() async => throw StateError('private-token');
}

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePermissions service;
  late MemoryPermissionPromptStore store;
  late WidgetReadinessController controller;
  late FakeAuth auth;
  late FakeCouples couples;
  late PairingController pairing;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakePermissions();
    store = MemoryPermissionPromptStore();
    controller = WidgetReadinessController(
      service: service,
      promptStore: store,
    );
    auth = FakeAuth()..identity = 'me';
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
  });

  tearDown(() {
    controller.dispose();
    pairing.dispose();
    auth.dispose();
  });

  Future<void> bindComplete() async {
    await pairing.initialize();
    controller.bindPairing(pairing);
    await controller.initialize();
  }

  test(
    'granted first launch does not prompt or request and has no invented widget',
    () async {
      service.access = NotificationAccess.granted;
      expect(controller.initialised, isFalse);
      expect(controller.notificationAccess, NotificationAccess.unknown);
      expect(controller.widgetInstalled, isFalse);
      await controller.initialize();
      expect(controller.initialised, isTrue);
      expect(controller.notificationAccess, NotificationAccess.granted);
      expect(controller.shouldPrompt, isFalse);
      expect(controller.widgetInstalled, isFalse);
      expect(service.events, ['status']);
      await controller.initialize();
      expect(service.events, ['status']);
    },
  );

  test(
    'denied asks once across controllers; request persists before OS and retry is explicit',
    () async {
      controller.dispose();
      final preferences = SharedPreferencesPermissionPromptStore();
      controller = WidgetReadinessController(
        service: service,
        promptStore: preferences,
      );
      await controller.initialize();
      expect(controller.shouldPrompt, isTrue);
      expect(service.events, ['status']);
      final gate = Completer<NotificationAccess>();
      service.requestGate = gate;
      final request = controller.requestNotifications();
      await settle();
      expect(
        await SharedPreferencesPermissionPromptStore().wasHandled(),
        isTrue,
      );
      expect(service.events.last, 'request');
      expect(controller.shouldPrompt, isFalse);
      gate.complete(NotificationAccess.denied);
      await request;
      controller.dispose();
      controller = WidgetReadinessController(
        service: service,
        promptStore: SharedPreferencesPermissionPromptStore(),
      );
      await controller.initialize();
      expect(controller.shouldPrompt, isFalse);
      expect(controller.notificationAccess, NotificationAccess.denied);
      service.requestGate = null;
      service.requestResult = NotificationAccess.granted;
      await controller.requestNotifications();
      expect(controller.notificationAccess, NotificationAccess.granted);
      expect(service.events.where((event) => event == 'request').length, 2);
    },
  );

  test(
    'Later is persisted and resume/pairing never requests the OS permission',
    () async {
      controller.dispose();
      controller = WidgetReadinessController(
        service: service,
        promptStore: SharedPreferencesPermissionPromptStore(),
      );
      await controller.initialize();
      await controller.deferPrompt();
      controller.dispose();
      controller = WidgetReadinessController(
        service: service,
        promptStore: SharedPreferencesPermissionPromptStore(),
      );
      await bindComplete();
      controller.setForeground(false);
      controller.setForeground(true);
      await settle();
      expect(controller.shouldPrompt, isFalse);
      expect(service.events, isNot(contains('request')));
      expect(service.events, isNot(contains('pin')));
    },
  );

  test('permanent denial opens settings without assuming a grant', () async {
    service.access = NotificationAccess.permanentlyDenied;
    await controller.initialize();
    await controller.deferPrompt();
    await controller.openSettings();
    expect(service.events, ['status', 'settings']);
    expect(controller.notificationAccess, NotificationAccess.permanentlyDenied);
    expect(controller.shouldPrompt, isFalse);
    service.settings = false;
    await controller.openSettings();
    expect(controller.error, isNotNull);
  });

  test('revocation on resume updates status without a repeat prompt', () async {
    store.handled = true;
    service.access = NotificationAccess.granted;
    service.installed = true;
    await bindComplete();
    controller.setForeground(false);
    service.access = NotificationAccess.denied;
    service.installed = false;
    controller.setForeground(true);
    await settle();
    expect(controller.notificationAccess, NotificationAccess.denied);
    expect(controller.widgetInstalled, isFalse);
    expect(controller.shouldPrompt, isFalse);
    expect(service.events.where((event) => event == 'status').length, 2);
    expect(service.events, isNot(contains('request')));
  });

  test(
    'unknown, unsupported and failed status never auto-prompt or leak error text',
    () async {
      for (final access in [
        NotificationAccess.unknown,
        NotificationAccess.unsupported,
      ]) {
        service.access = access;
        await controller.refresh();
        expect(controller.shouldPrompt, isFalse);
      }
      service.failure = StateError('secret-token/private/path');
      await controller.refresh();
      expect(controller.notificationAccess, NotificationAccess.unknown);
      expect(controller.shouldPrompt, isFalse);
      expect(controller.initialised, isTrue);
      expect(controller.error.toString(), isNot(contains('secret-token')));
      expect(service.events, isNot(contains('request')));
    },
  );

  test(
    'failed OS request stays handled and never retries automatically',
    () async {
      await controller.initialize();
      service.requestFailure = StateError('private-platform-token');
      await controller.requestNotifications();
      expect(store.handled, isTrue);
      expect(controller.shouldPrompt, isFalse);
      expect(
        controller.error.toString(),
        isNot(contains('private-platform-token')),
      );
      controller.setForeground(false);
      controller.setForeground(true);
      await settle();
      expect(controller.shouldPrompt, isFalse);
      expect(service.events, ['status', 'request', 'status']);
    },
  );

  test('store failure hides automatic prompt and stops OS request', () async {
    controller.dispose();
    controller = WidgetReadinessController(
      service: service,
      promptStore: FailingPromptStore(),
    );
    await controller.initialize();
    expect(controller.shouldPrompt, isFalse);
    expect(controller.error.toString(), isNot(contains('private-token')));
    await controller.requestNotifications();
    expect(service.events, ['status']);
    expect(controller.error.toString(), isNot(contains('private-token')));
  });

  test(
    'pending to verified complete queries once; repeated paired snapshots do not query',
    () async {
      couples.couple = Couple(id: 'couple', memberIds: ['me']);
      service.installed = true;
      controller.bindPairing(pairing);
      await pairing.initialize();
      await controller.initialize();
      expect(controller.widgetInstalled, isFalse);
      expect(controller.pinSupported, isFalse);
      expect(service.events, ['status']);
      couples.couple = Couple(id: 'couple', memberIds: ['me', 'partner']);
      await pairing.refresh();
      await settle();
      expect(controller.widgetInstalled, isTrue);
      expect(controller.pinSupported, isTrue);
      expect(service.events, ['status', 'status', 'installed', 'pinSupport']);
      await pairing.refresh();
      couples.couple = couples.couple!.copyWith(partnerNickname: 'Love');
      await pairing.refresh();
      await settle();
      expect(service.events, ['status', 'status', 'installed', 'pinSupport']);
      expect(service.events, isNot(contains('request')));
    },
  );

  test(
    'wrong membership, duplicated members, and unloaded pairing cannot show readiness',
    () async {
      service.installed = true;
      controller.bindPairing(pairing);
      await controller.initialize();
      expect(controller.widgetInstalled, isFalse);
      for (final members in [
        ['stranger', 'partner'],
        ['me', 'me'],
        ['me', ''],
      ]) {
        couples.couple = Couple(id: 'couple', memberIds: members);
        await pairing.initialize();
        await settle();
        expect(controller.widgetInstalled, isFalse);
        expect(controller.pinSupported, isFalse);
      }
      expect(service.events, ['status']);
      await controller.addWidget();
      expect(service.events, ['status']);
    },
  );

  test(
    'old account query is discarded; only new current pair shows badges',
    () async {
      final gate = Completer<bool>();
      service.widgetGate = gate;
      await pairing.initialize();
      controller.bindPairing(pairing);
      final initial = controller.initialize();
      await settle();
      expect(service.events, ['status', 'installed']);
      couples.couple = Couple(
        id: 'other-couple',
        memberIds: ['other', 'partner'],
      );
      auth.change('other');
      expect(controller.widgetInstalled, isFalse);
      expect(controller.notificationAccess, NotificationAccess.unknown);
      gate.complete(true);
      await initial;
      await settle();
      expect(controller.widgetInstalled, isFalse);
      expect(controller.notificationAccess, NotificationAccess.denied);
      expect(service.maxActive, 1);
      expect(service.events.where((event) => event == 'installed').length, 2);
      expect(service.events.where((event) => event == 'pinSupport').length, 1);
    },
  );

  test(
    'requests are single-flight and resume read waits for OS dialog',
    () async {
      await controller.initialize();
      final gate = Completer<NotificationAccess>();
      service.requestGate = gate;
      final first = controller.requestNotifications();
      final second = controller.requestNotifications();
      expect(identical(first, second), isTrue);
      await settle();
      controller.setForeground(false);
      controller.setForeground(true);
      await settle();
      expect(service.events, ['status', 'request']);
      expect(controller.busy, isTrue);
      service.access = NotificationAccess.granted;
      gate.complete(NotificationAccess.granted);
      await first;
      await settle();
      expect(service.events, ['status', 'request', 'status']);
      expect(service.maxActive, 1);
      expect(controller.notificationAccess, NotificationAccess.granted);
      expect(controller.busy, isFalse);
      expect(controller.shouldPrompt, isFalse);
    },
  );

  test(
    'refresh and request serialize, and a fresh resume read is not lost',
    () async {
      final gate = Completer<NotificationAccess>();
      service.statusGate = gate;
      final initial = controller.initialize();
      final refresh = controller.refresh();
      expect(identical(initial, refresh), isTrue);
      await settle();
      final request = controller.requestNotifications();
      controller.setForeground(false);
      controller.setForeground(true);
      await settle();
      expect(service.events, ['status']);
      gate.complete(NotificationAccess.denied);
      await initial;
      await request;
      await settle();
      expect(service.events, ['status', 'request', 'status']);
      expect(service.maxActive, 1);
    },
  );

  test(
    'pin request neither invents installation nor depends on notification grant',
    () async {
      await bindComplete();
      expect(controller.notificationAccess, NotificationAccess.denied);
      await controller.addWidget();
      expect(service.events, contains('pin'));
      expect(controller.widgetInstalled, isFalse);
      expect(service.events, isNot(contains('request')));
      service.installed = true;
      await controller.refresh();
      expect(controller.widgetInstalled, isTrue);
      service.pin = false;
      final pins = service.events.where((event) => event == 'pin').length;
      await controller.addWidget();
      expect(controller.pinSupported, isFalse);
      expect(service.events.where((event) => event == 'pin').length, pins);
    },
  );

  test('dispose suppresses late notifications and queued calls', () async {
    await controller.initialize();
    final gate = Completer<NotificationAccess>();
    service.requestGate = gate;
    var notifications = 0;
    controller.addListener(() => notifications++);
    final request = controller.requestNotifications();
    await settle();
    controller.setForeground(false);
    controller.setForeground(true);
    controller.dispose();
    final before = notifications;
    gate.complete(NotificationAccess.granted);
    await request;
    await settle();
    expect(notifications, before);
    expect(service.events, ['status', 'request']);
    // Replace the already-disposed instance for the common tearDown.
    controller = WidgetReadinessController(service: service);
  });

  test(
    'dispose during first status query does not publish a late result',
    () async {
      final gate = Completer<NotificationAccess>();
      service.statusGate = gate;
      var notifications = 0;
      controller.addListener(() => notifications++);
      final initial = controller.initialize();
      await settle();
      controller.dispose();
      final before = notifications;
      gate.complete(NotificationAccess.granted);
      await initial;
      expect(notifications, before);
      expect(controller.notificationAccess, NotificationAccess.unknown);
      expect(controller.initialised, isFalse);
      controller = WidgetReadinessController(service: service);
    },
  );

  test('unbinding clears badges and removes pairing subscription', () async {
    service.installed = true;
    await bindComplete();
    expect(controller.widgetInstalled, isTrue);
    controller.bindPairing(null);
    await settle();
    expect(controller.widgetInstalled, isFalse);
    expect(controller.pinSupported, isFalse);
    final count = service.events.length;
    auth.change('new-user');
    await settle();
    expect(service.events.length, count);
  });
}
