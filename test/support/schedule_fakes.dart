import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/data/native_widget_timeline.dart';
import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall_client/closecall_client.dart';

import 'live_fakes.dart';

final scheduleEpoch = DateTime.utc(2026, 10, 3, 12);

WidgetScheduleEntry scheduleEntry({
  String id = 'schedule',
  String asset = 'scheduled',
  int from = 10,
  int until = 20,
  int created = 0,
  String recipient = 'me',
}) => WidgetScheduleEntry(
  scheduleId: id,
  assetId: asset,
  senderId: recipient == 'me' ? 'partner' : 'me',
  recipientId: recipient,
  activeFrom: scheduleEpoch.add(Duration(seconds: from)),
  activeUntil: scheduleEpoch.add(Duration(seconds: until)),
  createdAt: scheduleEpoch.add(Duration(seconds: created)),
);

WidgetTimeline scheduleTimeline({
  String recipient = 'me',
  String? fallback = 'fallback',
  List<WidgetScheduleEntry> schedules = const [],
  DateTime? now,
  String couple = 'couple',
}) => WidgetTimeline(
  coupleId: couple,
  recipientId: recipient,
  fallbackAssetId: fallback,
  schedules: schedules,
  serverTime: now ?? scheduleEpoch,
);

class FakeSchedules implements ScheduleRepository {
  WidgetTimeline own = scheduleTimeline();
  WidgetTimeline partner = scheduleTimeline(
    recipient: 'partner',
    fallback: 'partner-only',
  );
  final stream = StreamController<WidgetTimeline>.broadcast(sync: true);
  final oldStreams = <StreamController<WidgetTimeline>>[];
  Completer<WidgetTimeline>? pendingCurrent;
  Object? currentFailure;
  Object? createFailure;
  final creates = <(String, DateTime, DateTime, String)>[];
  final cancellations = <String>[];
  final fallbacks = <String>[];
  int watches = 0;

  @override
  Future<WidgetTimeline> currentTimeline() async {
    if (currentFailure != null) throw currentFailure!;
    return pendingCurrent == null ? own : pendingCurrent!.future;
  }

  @override
  Future<WidgetTimeline> partnerTimeline() async => partner;
  @override
  Future<WidgetScheduleEntry> createSchedule(
    String assetId,
    DateTime from,
    DateTime until,
    String requestId,
  ) async {
    creates.add((assetId, from, until, requestId));
    if (createFailure != null) throw createFailure!;
    return scheduleEntry(
      asset: assetId,
      recipient: 'partner',
    ).copyWith(activeFrom: from, activeUntil: until);
  }

  @override
  Future<WidgetTimeline> setFallback(String assetId) async {
    fallbacks.add(assetId);
    own = own.copyWith(fallbackAssetId: assetId);
    return own;
  }

  @override
  Future<void> cancelSchedule(String scheduleId) async {
    cancellations.add(scheduleId);
    own = own.copyWith(
      schedules: own.schedules
          .where((s) => s.scheduleId != scheduleId)
          .toList(),
    );
    partner = partner.copyWith(
      schedules: partner.schedules
          .where((s) => s.scheduleId != scheduleId)
          .toList(),
    );
  }

  @override
  Stream<WidgetTimeline> watchTimeline() {
    watches++;
    return stream.stream;
  }

  Future<void> dispose() async => stream.close();
}

class ControlledScheduleMedia extends FakeMedia {
  final pending = <String, Completer<Uint8List>>{};
  final photos = <String, Uint8List>{};
  @override
  Future<Uint8List> downloadPhoto(String assetId) async {
    downloads.add(assetId);
    if (downloadFailure != null) throw downloadFailure!;
    return pending[assetId]?.future ?? photos[assetId] ?? testPng;
  }
}

class FakeNativeTimeline implements NativeWidgetTimeline {
  FakeNativeTimeline(this.events, {this.supported = true});
  final List<String> events;
  @override
  final bool supported;
  final payloads = <Map<String, Object?>>[];
  Completer<void>? pendingCache;
  Map<String, Object?>? persisted;
  Object? disableFailure;
  Object? clearFailure;

  @override
  Future<void> cacheTimeline(Map<String, Object?> payload) async {
    events.add('cache-start');
    payloads.add(payload);
    if (pendingCache != null) await pendingCache!.future;
    persisted = payload;
    events.add('cache-done');
  }

  @override
  Future<void> disableTimeline() async {
    events.add('disable');
    if (disableFailure != null) throw disableFailure!;
    persisted = null;
  }

  @override
  Future<void> clearTimeline() async {
    events.add('clear-timeline');
    if (clearFailure != null) throw clearFailure!;
    persisted = null;
  }
}

/// Only restoration-focused tests opt into the new Android capability.
class FakeRestoringTimeline extends FakeNativeTimeline
    implements ScopedWidgetRestoration {
  FakeRestoringTimeline(super.events);
  String? ownerScope;
  String? ownerAsset;
  Uint8List? displayed;
  bool fresh = true;
  bool suspended = false;
  final restoredScopes = <String>[];

  @override
  Future<void> suspendForStartup() async {
    events.add('suspend');
    suspended = true;
  }

  @override
  Future<RestoredWidgetPhoto?> restoreScope(
    String scope, {
    required bool allowPartnerPhoto,
  }) async {
    restoredScopes.add(scope);
    events.add('restore');
    if (!fresh ||
        ownerScope != scope ||
        displayed == null ||
        (ownerAsset != null && !allowPartnerPhoto)) {
      await clearTimeline();
      return null;
    }
    return RestoredWidgetPhoto(
      assetId: ownerAsset,
      bytes: Uint8List.fromList(displayed!),
    );
  }

  @override
  Future<void> recordPhotoOwner(String scope, {String? assetId}) async {
    events.add('record-owner');
    ownerScope = scope;
    ownerAsset = assetId;
  }

  @override
  Future<void> clearTimeline() async {
    await super.clearTimeline();
    displayed = null;
    ownerScope = ownerAsset = null;
  }
}

class ScheduleHarness {
  final auth = FakeAuth();
  final couples = FakeCouples();
  final repository = FakeSchedules();
  final photos = ControlledScheduleMedia();
  final events = <String>[];
  final applied = <Uint8List>[];
  late final PairingController pairing;
  late final ScheduleController controller;
  late final LocalWidgetWriter writer;
  late final FakeNativeTimeline native;
  late final MediaController media;
  Duration elapsed = Duration.zero;
  DateTime wall = DateTime.utc(2099);
  Completer<void>? pendingApply;
  int clears = 0;
  int requestIds = 0;

  Future<void> initialize({bool signedIn = true, bool android = true}) async {
    if (signedIn) auth.change('me');
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    native = FakeNativeTimeline(events, supported: android);
    writer = LocalWidgetWriter(
      timeline: native,
      applyPhoto: (photo) async {
        events.add('photo-start');
        if (pendingApply != null) await pendingApply!.future;
        applied.add(Uint8List.fromList(photo));
        events.add('photo-done');
      },
      clearPhoto: () async {
        clears++;
        events.add('clear-photo');
        applied.clear();
      },
    );
    controller = ScheduleController(
      pairing: pairing,
      repository: repository,
      mediaRepository: photos,
      localWriter: writer,
      now: () => wall,
      elapsed: () => elapsed,
      requestId: () => 'request-${++requestIds}',
    );
    media = MediaController(pairing: pairing, repository: photos);
    // Let the constructor's refresh settle without real timers/plugins.
    for (var i = 0; i < 20; i++) {
      await Future<void>.value();
    }
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    media.dispose();
    controller.dispose();
    pairing.dispose();
    auth.dispose();
    await repository.dispose();
    for (var i = 0; i < 20; i++) {
      await Future<void>.value();
    }
  }
}
