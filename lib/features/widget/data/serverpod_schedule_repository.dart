import 'package:closecall_client/closecall_client.dart';
import 'schedule_repository.dart';

class ServerpodScheduleRepository
    implements ScheduleRepository, DeliveryConsentRepository {
  ServerpodScheduleRepository(Client client)
    : this.withCalls(
        current: client.widgetSchedule.currentTimeline,
        partner: client.widgetSchedule.partnerTimeline,
        create: client.widgetSchedule.createSchedule,
        fallback: client.widgetSchedule.setFallback,
        cancel: client.widgetSchedule.cancelSchedule,
        watch: client.widgetSchedule.watchTimeline,
        consent: client.widgetSchedule.setDeliveryConsent,
        delivery: client.widgetSchedule.getDeliveryState,
      );

  /// Inject generated RPC signatures without a transport or Flutter plugins.
  ServerpodScheduleRepository.withCalls({
    required Future<WidgetTimeline> Function() current,
    required Future<WidgetTimeline> Function() partner,
    required Future<WidgetScheduleEntry> Function(
      String,
      DateTime,
      DateTime,
      String,
    )
    create,
    required Future<WidgetTimeline> Function(String) fallback,
    required Future<void> Function(String) cancel,
    required Stream<WidgetTimeline> Function() watch,
    Future<WidgetDeliveryState> Function(bool)? consent,
    Future<WidgetDeliveryState> Function()? delivery,
  }) : this._(
         current,
         partner,
         create,
         fallback,
         cancel,
         watch,
         consent,
         delivery,
       );

  ServerpodScheduleRepository._(
    this._current,
    this._partner,
    this._create,
    this._fallback,
    this._cancel,
    this._watch,
    this._consent,
    this._delivery,
  );

  final Future<WidgetTimeline> Function() _current;
  final Future<WidgetTimeline> Function() _partner;
  final Future<WidgetScheduleEntry> Function(String, DateTime, DateTime, String)
  _create;
  final Future<WidgetTimeline> Function(String) _fallback;
  final Future<void> Function(String) _cancel;
  final Stream<WidgetTimeline> Function() _watch;
  final Future<WidgetDeliveryState> Function(bool)? _consent;
  final Future<WidgetDeliveryState> Function()? _delivery;
  @override
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled) =>
      _consent?.call(enabled) ??
      Future.error(UnsupportedError('Delivery consent is unavailable.'));
  @override
  Future<WidgetDeliveryState> getDeliveryState() =>
      _delivery?.call() ??
      Future.error(UnsupportedError('Delivery consent is unavailable.'));
  @override
  Future<WidgetTimeline> currentTimeline() => _current();
  @override
  Future<WidgetTimeline> partnerTimeline() => _partner();
  @override
  Future<WidgetScheduleEntry> createSchedule(
    String assetId,
    DateTime activeFrom,
    DateTime activeUntil,
    String requestId,
  ) => _create(assetId, activeFrom.toUtc(), activeUntil.toUtc(), requestId);
  @override
  Future<WidgetTimeline> setFallback(String assetId) => _fallback(assetId);
  @override
  Future<void> cancelSchedule(String scheduleId) => _cancel(scheduleId);
  @override
  Stream<WidgetTimeline> watchTimeline() => _watch();
}
