import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:closecall/core/permissions/widget_readiness_controller.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

class _Permissions implements WidgetPermissionService {
  NotificationAccess access = NotificationAccess.denied;
  bool installed = false;
  bool pinSupported = true;
  bool failReads = false;
  int requests = 0;
  int reads = 0;
  int pins = 0;
  int settings = 0;

  @override
  Future<NotificationAccess> notificationStatus() async {
    reads++;
    if (failReads) throw StateError('private native failure');
    return access;
  }

  @override
  Future<NotificationAccess> requestNotifications() async {
    requests++;
    return access;
  }

  @override
  Future<bool> hasInstalledWidget() async => installed;
  @override
  Future<bool> canPinWidget() async => pinSupported;
  @override
  Future<void> requestPinWidget() async => pins++;
  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

class _ConsentSchedules extends FakeSchedules
    implements DeliveryConsentRepository {
  final writes = <bool>[];
  WidgetDeliveryState get state => WidgetDeliveryState(
    coupleId: 'couple',
    recipientId: 'me',
    autoUpdateEnabled: own.autoUpdateEnabled,
    version: writes.length,
  );

  @override
  Future<WidgetDeliveryState> getDeliveryState() async => state;
  @override
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled) async {
    writes.add(enabled);
    own = own.copyWith(autoUpdateEnabled: enabled);
    return state;
  }
}

void main() {
  Future<void> openSetup(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('widget-setup-summary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('widget-setup-summary')));
    await tester.pumpAndSettle();
  }

  Future<void> scrollSheet(
    WidgetTester tester,
    Finder target,
    double delta,
  ) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  late FakeAuth auth;
  late FakeCouples couples;
  late PairingController pairing;
  late _Permissions service;
  late WidgetReadinessController readiness;

  setUp(() async {
    auth = FakeAuth()..change('me');
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    service = _Permissions();
    readiness = WidgetReadinessController(
      service: service,
      promptStore: MemoryPermissionPromptStore()..handled = true,
    )..bindPairing(pairing);
    await readiness.initialize();
  });
  tearDown(() {
    readiness.dispose();
    pairing.dispose();
    auth.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    MediaController? media,
    ScheduleController? schedules,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: WidgetTabScreen(
          liveMode: true,
          pairing: pairing,
          media: media,
          schedules: schedules,
          readiness: readiness,
        ),
      ),
    ),
  );

  testWidgets(
    'paired setup checks OS state without asking or granting consent',
    (tester) async {
      late _ConsentSchedules repository;
      late ScheduleController schedules;
      late MediaController media;
      await tester.runAsync(() async {
        repository = _ConsentSchedules();
        final photos = FakeMedia();
        schedules = ScheduleController(
          pairing: pairing,
          repository: repository,
          mediaRepository: photos,
          localWriter: LocalWidgetWriter(
            timeline: FakeNativeTimeline([], supported: false),
            applyPhoto: (_) async {},
            clearPhoto: () async {},
          ),
          now: () => scheduleEpoch,
        );
        media = MediaController(pairing: pairing, repository: photos);
        for (var i = 0; i < 30; i++) {
          await Future<void>.value();
        }
      });
      await show(tester, media: media, schedules: schedules);
      await tester.pumpAndSettle();
      expect(find.text('Widget setup'), findsOneWidget);
      expect(find.text('Notifications: off'), findsNothing);
      expect(
        find.byKey(const Key('widget-notifications-action')),
        findsNothing,
      );
      expect(service.requests, 0);
      expect(repository.writes, isEmpty);
      expect(schedules.partnerUpdatesEnabled, isFalse);

      await tester.scrollUntilVisible(
        find.byKey(const Key('hub-partner-updates')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hub-partner-updates')));
      await tester.pumpAndSettle();
      final allow = tester.widget<SwitchListTile>(
        find.byKey(const Key('partner-updates-toggle')),
      );
      expect(allow.onChanged, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('partner-updates-toggle')));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.writes, [true]);
      expect(schedules.partnerUpdatesEnabled, isTrue);
      expect(service.access, NotificationAccess.denied);
      await tester.tap(find.byTooltip('Close Photos from your partner'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('hub-send-to-partner')),
        -150,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const Key('hub-send-to-partner')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNotNull,
      );
      expect(service.requests, 0);
      await tester.pumpWidget(const SizedBox());
      media.dispose();
      schedules.dispose();
      await repository.dispose();
    },
  );

  testWidgets(
    'permanent denial offers Settings; return rechecks actual grant',
    (tester) async {
      service.access = NotificationAccess.permanentlyDenied;
      service.installed = true;
      await tester.runAsync(readiness.refresh);
      await show(tester);
      await tester.pumpAndSettle();
      await openSetup(tester);
      await scrollSheet(
        tester,
        find.byKey(const Key('widget-notifications-action')),
        100,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('widget-notifications-action')));
        await readiness.refresh();
      });
      await tester.pumpAndSettle();
      expect(service.settings, 1);
      expect(service.requests, 0);
      expect(
        readiness.notificationAccess,
        NotificationAccess.permanentlyDenied,
      );
      expect(find.byKey(const Key('widget-setup-ready')), findsNothing);
      await tester.runAsync(() async {
        readiness.setForeground(false);
        service.access = NotificationAccess.granted;
        readiness.setForeground(true);
        await readiness.refresh();
      });
      await tester.pumpAndSettle();
      expect(readiness.widgetInstalled, isTrue);
      await scrollSheet(
        tester,
        find.byKey(const Key('widget-setup-ready')),
        -200,
      );
      expect(find.byKey(const Key('widget-setup-ready')), findsOneWidget);
      expect(find.byKey(const Key('widget-setup-card')), findsNothing);
      expect(find.textContaining('Closed-app photo delivery'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('pin request is not installation; only a later read is ready', (
    tester,
  ) async {
    service.access = NotificationAccess.granted;
    await tester.runAsync(readiness.refresh);
    await show(tester);
    await tester.pumpAndSettle();
    await openSetup(tester);
    await scrollSheet(tester, find.byKey(const Key('widget-add-action')), 100);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('widget-add-action')));
      await readiness.refresh();
    });
    await tester.pumpAndSettle();
    expect(service.pins, 1);
    expect(readiness.widgetInstalled, isFalse);
    expect(find.byKey(const Key('widget-setup-ready')), findsNothing);
    service.installed = true;
    await tester.runAsync(readiness.refresh);
    await tester.pumpAndSettle();
    expect(readiness.widgetInstalled, isTrue);
    await scrollSheet(
      tester,
      find.byKey(const Key('widget-setup-ready')),
      -200,
    );
    expect(find.byKey(const Key('widget-setup-ready')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unsupported pinning offers manual launcher instructions', (
    tester,
  ) async {
    service.pinSupported = false;
    await tester.runAsync(readiness.refresh);
    await show(tester);
    await tester.pumpAndSettle();
    await openSetup(tester);
    await scrollSheet(
      tester,
      find.byKey(const Key('widget-manual-instructions')),
      100,
    );
    expect(find.byKey(const Key('widget-add-action')), findsNothing);
    expect(find.textContaining('Touch and hold an empty spot'), findsOneWidget);
    expect(service.pins, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unpaired tab does not show full partner widget setup', (
    tester,
  ) async {
    couples.couple = Couple(id: 'couple', memberIds: ['me']);
    await tester.runAsync(pairing.refresh);
    await tester.runAsync(readiness.refresh);
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('widget-setup-card')), findsNothing);
    expect(find.byKey(const Key('widget-setup-ready')), findsNothing);
    expect(service.requests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('setup fits width $width and text scale 2', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, scale: 2);
      await tester.pumpAndSettle();
      await openSetup(tester);
      await scrollSheet(
        tester,
        find.byKey(const Key('widget-check-setup')),
        180,
      );
      expect(tester.takeException(), isNull);
      service.installed = true;
      service.access = NotificationAccess.granted;
      await tester.runAsync(readiness.refresh);
      await tester.pumpAndSettle();
      await scrollSheet(
        tester,
        find.byKey(const Key('widget-setup-ready')),
        -180,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('read failure is recoverable without exposing native errors', (
    tester,
  ) async {
    service.failReads = true;
    await tester.runAsync(readiness.refresh);
    await show(tester);
    await tester.pumpAndSettle();
    await openSetup(tester);
    await scrollSheet(
      tester,
      find.byKey(const Key('widget-readiness-error')),
      100,
    );
    expect(find.textContaining('private native failure'), findsNothing);
    service.failReads = false;
    await scrollSheet(tester, find.byKey(const Key('widget-check-setup')), 100);
    await tester.ensureVisible(find.byKey(const Key('widget-check-setup')));
    await tester.pumpAndSettle();
    final previousReads = service.reads;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('widget-check-setup')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(service.reads, previousReads + 1);
    expect(readiness.error, isNull);
    expect(service.requests, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
