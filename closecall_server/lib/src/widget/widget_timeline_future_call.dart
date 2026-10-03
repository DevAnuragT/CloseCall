import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'widget_timeline_service.dart';

/// Generated, typed start/end wakeups. Repeated or cancelled wakes are safe:
/// there is no historical payload to apply, only current database truth.
class WidgetTimelineFutureCall extends FutureCall {
  Future<void> wake(Session session, String scheduleId) async {
    final id = parseScheduleUuid(scheduleId);
    if (id == null) return;
    final record = await WidgetScheduleRecord.db.findById(session, id);
    if (record == null) return;
    final member = await CoupleMember.db.findById(session, record.recipientMemberId);
    if (member == null || member.coupleId != record.coupleId) return;
    try {
      // Re-resolve even if cancelled or this is a late/repeated end wake.
      final timeline = await WidgetTimelineService().timeline(session, member.userIdentifier);
      await notifyTimeline(session, timeline.recipientId);
    } on ScheduleFailure catch (_) {
      // Membership disappeared or is incomplete. Never broadcast private data.
    }
  }
}
