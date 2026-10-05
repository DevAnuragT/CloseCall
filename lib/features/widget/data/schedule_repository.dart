import 'package:closecall_client/closecall_client.dart';

abstract interface class ScheduleRepository {
  Future<WidgetTimeline> currentTimeline();
  Future<WidgetTimeline> partnerTimeline();
  Future<WidgetScheduleEntry> createSchedule(
    String assetId,
    DateTime activeFrom,
    DateTime activeUntil,
    String requestId,
  );
  Future<WidgetTimeline> setFallback(String assetId);
  Future<void> cancelSchedule(String scheduleId);
  Stream<WidgetTimeline> watchTimeline();
}

/// Account-scoped consent, separate from a device's local auto-sync opt-in.
/// Optional so existing schedule-only adapters and fakes remain compatible.
abstract interface class DeliveryConsentRepository {
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled);
  Future<WidgetDeliveryState> getDeliveryState();
}

String scheduleErrorMessage(Object error) {
  if (error is ScheduleFailure) {
    return switch (error.code) {
      'not_paired' => 'Complete pairing before using photo schedules.',
      'asset_not_found' =>
        'That private photo is unavailable. Refresh private photos.',
      'invalid_window' =>
        'Choose a valid start and end, with the end after the start.',
      'invalid_request_id' =>
        'The schedule request ID was rejected. Discard the pending request and start again.',
      'request_conflict' =>
        'This request ID belongs to a different schedule. Discard it before starting again.',
      'schedule_not_found' =>
        'That schedule is unavailable or cannot be cancelled by this account. Refresh timelines.',
      'quota_exceeded' =>
        'Your schedule quota has been reached. Cancel an unused window first.',
      _ => 'Schedule request failed: ${error.code}',
    };
  }
  return 'Schedule operation failed: $error';
}
