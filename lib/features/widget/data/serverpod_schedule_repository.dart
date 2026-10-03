import 'package:closecall_client/closecall_client.dart';
import 'schedule_repository.dart';

class ServerpodScheduleRepository implements ScheduleRepository {
  ServerpodScheduleRepository(this.client);
  final Client client;
  @override
  Future<WidgetTimeline> currentTimeline() =>
      client.widgetSchedule.currentTimeline();
  @override
  Future<WidgetTimeline> partnerTimeline() =>
      client.widgetSchedule.partnerTimeline();
  @override
  Future<WidgetScheduleEntry> createSchedule(
    String assetId,
    DateTime activeFrom,
    DateTime activeUntil,
    String requestId,
  ) => client.widgetSchedule.createSchedule(
    assetId,
    activeFrom.toUtc(),
    activeUntil.toUtc(),
    requestId,
  );
  @override
  Future<WidgetTimeline> setFallback(String assetId) =>
      client.widgetSchedule.setFallback(assetId);
  @override
  Future<void> cancelSchedule(String scheduleId) =>
      client.widgetSchedule.cancelSchedule(scheduleId);
  @override
  Stream<WidgetTimeline> watchTimeline() =>
      client.widgetSchedule.watchTimeline();
}
