import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'widget_timeline_service.dart';

class WidgetScheduleEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  final _service = WidgetTimelineService();

  Future<WidgetTimeline> currentTimeline(Session session) =>
    _service.timeline(session, session.authenticated!.userIdentifier);

  Future<WidgetTimeline> partnerTimeline(Session session) =>
    _service.timeline(session, session.authenticated!.userIdentifier, partner: true);

  Future<WidgetScheduleEntry> createSchedule(Session session, String assetId,
    DateTime activeFrom, DateTime activeUntil, String requestId) =>
    _service.create(session, session.authenticated!.userIdentifier, assetId,
      activeFrom, activeUntil, requestId);

  Future<WidgetTimeline> setFallback(Session session, String assetId) =>
    _service.fallback(session, session.authenticated!.userIdentifier, assetId);

  Future<void> cancelSchedule(Session session, String scheduleId) =>
    _service.cancel(session, session.authenticated!.userIdentifier, scheduleId);

  /// Local notifications reduce latency, precise timers handle boundaries, and
  /// one-second DB reconciliation covers missed events/restarts/other pods.
  /// Every snapshot rechecks the CURRENT user's complete membership.
  Stream<WidgetTimeline> watchTimeline(Session session) {
    final user = session.authenticated!.userIdentifier;
    late StreamController<WidgetTimeline> output;
    StreamSubscription<TimelineNotice>? notices;
    Timer? poll;
    Timer? boundary;
    Future<void>? pending;
    var closed = false;
    var running = false;
    var dirty = false;
    String? previous;

    void refresh() {
      if (closed) return;
      dirty = true;
      if (running) return;
      running = true;
      pending = (() async {
        try {
          while (dirty && !closed) {
            dirty = false;
            final timeline = await currentTimeline(session);
            if (closed) return;
            final json = timeline.toJson()..remove('serverTime');
            final fingerprint = jsonEncode(json);
            if (fingerprint != previous) {
              previous = fingerprint;
              output.add(timeline);
            }
            boundary?.cancel();
            final now = clock.now().toUtc();
            final boundaries = timeline.schedules.expand((s) => [s.activeFrom, s.activeUntil])
              .where((at) => at.isAfter(now)).toList()..sort();
            if (boundaries.isNotEmpty) {
              boundary = Timer(boundaries.first.difference(now), refresh);
            }
          }
        } catch (error, stack) {
          if (!closed) {
            output.addError(error, stack);
            unawaited(output.close());
          }
        } finally { running = false; }
      })();
    }

    output = StreamController<WidgetTimeline>(
      onListen: () {
        // Subscribe BEFORE reading the initial repeatable-read snapshot.
        notices = session.messages.createStream<TimelineNotice>(timelineChannel(user))
          .listen((notice) { if (notice.recipientId == user) refresh(); },
            onError: (Object _) { refresh(); });
        poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
        refresh();
      },
      onCancel: () async {
        closed = true;
        poll?.cancel();
        boundary?.cancel();
        await notices?.cancel();
        await pending;
      },
    );
    return output.stream;
  }
}
