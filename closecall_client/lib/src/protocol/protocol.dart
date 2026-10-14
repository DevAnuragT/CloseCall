/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:closecall_client/src/protocol/media/media_asset.dart'
    as _i7z5ta07;
import 'package:closecall_client/src/protocol/moments/moment_entry.dart'
    as _iw96ik5z;
import 'package:closecall_client/src/protocol/reminders/reminder_entry.dart'
    as _im86chxx;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'auth/account_state.dart' as _ib26upii;
import 'media/media_asset.dart' as _ijjfwapm;
import 'media/media_failure.dart' as _iuzipihh;
import 'moments/moment_entry.dart' as _iq4regyx;
import 'moments/moment_failure.dart' as _ilmm6qir;
import 'mood/mood_failure.dart' as _ievswv9n;
import 'mood/mood_state.dart' as _i3uwx2a4;
import 'pairing/pairing_failure.dart' as _ium95mnn;
import 'pairing/pairing_state.dart' as _iyyqlhox;
import 'push/push_failure.dart' as _i9648dgo;
import 'reminders/reminder_entry.dart' as _ipb0000r;
import 'reminders/reminder_failure.dart' as _ishkpy03;
import 'widget/schedule_failure.dart' as _ipjphtkx;
import 'widget/widget_delivery_state.dart' as _icmbt5hs;
import 'widget/widget_device_credential.dart' as _iv63qsae;
import 'widget/widget_schedule_entry.dart' as _iro0jbgj;
import 'widget/widget_send_receipt.dart' as _iezshfmm;
import 'widget/widget_timeline.dart' as _i8hd5s9w;
export 'auth/account_state.dart';
export 'media/media_asset.dart';
export 'media/media_failure.dart';
export 'moments/moment_entry.dart';
export 'moments/moment_failure.dart';
export 'mood/mood_failure.dart';
export 'mood/mood_state.dart';
export 'pairing/pairing_failure.dart';
export 'pairing/pairing_state.dart';
export 'push/push_failure.dart';
export 'reminders/reminder_entry.dart';
export 'reminders/reminder_failure.dart';
export 'widget/schedule_failure.dart';
export 'widget/widget_delivery_state.dart';
export 'widget/widget_device_credential.dart';
export 'widget/widget_schedule_entry.dart';
export 'widget/widget_send_receipt.dart';
export 'widget/widget_timeline.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _ib26upii.AccountState) {
      return _ib26upii.AccountState.fromJson(data) as T;
    }
    if (t == _ijjfwapm.MediaAsset) {
      return _ijjfwapm.MediaAsset.fromJson(data) as T;
    }
    if (t == _iuzipihh.MediaFailure) {
      return _iuzipihh.MediaFailure.fromJson(data) as T;
    }
    if (t == _iq4regyx.MomentEntry) {
      return _iq4regyx.MomentEntry.fromJson(data) as T;
    }
    if (t == _ilmm6qir.MomentFailure) {
      return _ilmm6qir.MomentFailure.fromJson(data) as T;
    }
    if (t == _ievswv9n.MoodFailure) {
      return _ievswv9n.MoodFailure.fromJson(data) as T;
    }
    if (t == _i3uwx2a4.MoodState) {
      return _i3uwx2a4.MoodState.fromJson(data) as T;
    }
    if (t == _ium95mnn.PairingFailure) {
      return _ium95mnn.PairingFailure.fromJson(data) as T;
    }
    if (t == _iyyqlhox.PairingState) {
      return _iyyqlhox.PairingState.fromJson(data) as T;
    }
    if (t == _i9648dgo.PushFailure) {
      return _i9648dgo.PushFailure.fromJson(data) as T;
    }
    if (t == _ipb0000r.ReminderEntry) {
      return _ipb0000r.ReminderEntry.fromJson(data) as T;
    }
    if (t == _ishkpy03.ReminderFailure) {
      return _ishkpy03.ReminderFailure.fromJson(data) as T;
    }
    if (t == _ipjphtkx.ScheduleFailure) {
      return _ipjphtkx.ScheduleFailure.fromJson(data) as T;
    }
    if (t == _icmbt5hs.WidgetDeliveryState) {
      return _icmbt5hs.WidgetDeliveryState.fromJson(data) as T;
    }
    if (t == _iv63qsae.WidgetDeviceCredential) {
      return _iv63qsae.WidgetDeviceCredential.fromJson(data) as T;
    }
    if (t == _iro0jbgj.WidgetScheduleEntry) {
      return _iro0jbgj.WidgetScheduleEntry.fromJson(data) as T;
    }
    if (t == _iezshfmm.WidgetSendReceipt) {
      return _iezshfmm.WidgetSendReceipt.fromJson(data) as T;
    }
    if (t == _i8hd5s9w.WidgetTimeline) {
      return _i8hd5s9w.WidgetTimeline.fromJson(data) as T;
    }
    if (t == _isc.getType<_ib26upii.AccountState?>()) {
      return (data != null ? _ib26upii.AccountState.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ijjfwapm.MediaAsset?>()) {
      return (data != null ? _ijjfwapm.MediaAsset.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iuzipihh.MediaFailure?>()) {
      return (data != null ? _iuzipihh.MediaFailure.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iq4regyx.MomentEntry?>()) {
      return (data != null ? _iq4regyx.MomentEntry.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ilmm6qir.MomentFailure?>()) {
      return (data != null ? _ilmm6qir.MomentFailure.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ievswv9n.MoodFailure?>()) {
      return (data != null ? _ievswv9n.MoodFailure.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i3uwx2a4.MoodState?>()) {
      return (data != null ? _i3uwx2a4.MoodState.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ium95mnn.PairingFailure?>()) {
      return (data != null ? _ium95mnn.PairingFailure.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iyyqlhox.PairingState?>()) {
      return (data != null ? _iyyqlhox.PairingState.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i9648dgo.PushFailure?>()) {
      return (data != null ? _i9648dgo.PushFailure.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ipb0000r.ReminderEntry?>()) {
      return (data != null ? _ipb0000r.ReminderEntry.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ishkpy03.ReminderFailure?>()) {
      return (data != null ? _ishkpy03.ReminderFailure.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ipjphtkx.ScheduleFailure?>()) {
      return (data != null ? _ipjphtkx.ScheduleFailure.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_icmbt5hs.WidgetDeliveryState?>()) {
      return (data != null
              ? _icmbt5hs.WidgetDeliveryState.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iv63qsae.WidgetDeviceCredential?>()) {
      return (data != null
              ? _iv63qsae.WidgetDeviceCredential.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iro0jbgj.WidgetScheduleEntry?>()) {
      return (data != null
              ? _iro0jbgj.WidgetScheduleEntry.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iezshfmm.WidgetSendReceipt?>()) {
      return (data != null ? _iezshfmm.WidgetSendReceipt.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i8hd5s9w.WidgetTimeline?>()) {
      return (data != null ? _i8hd5s9w.WidgetTimeline.fromJson(data) : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_iro0jbgj.WidgetScheduleEntry>) {
      return (data as List)
              .map((e) => deserialize<_iro0jbgj.WidgetScheduleEntry>(e))
              .toList()
          as T;
    }
    if (t == List<_i7z5ta07.MediaAsset>) {
      return (data as List)
              .map((e) => deserialize<_i7z5ta07.MediaAsset>(e))
              .toList()
          as T;
    }
    if (t == List<_iw96ik5z.MomentEntry>) {
      return (data as List)
              .map((e) => deserialize<_iw96ik5z.MomentEntry>(e))
              .toList()
          as T;
    }
    if (t == List<_im86chxx.ReminderEntry>) {
      return (data as List)
              .map((e) => deserialize<_im86chxx.ReminderEntry>(e))
              .toList()
          as T;
    }
    try {
      return _iacc.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iaic.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ib26upii.AccountState => 'AccountState',
      _ijjfwapm.MediaAsset => 'MediaAsset',
      _iuzipihh.MediaFailure => 'MediaFailure',
      _iq4regyx.MomentEntry => 'MomentEntry',
      _ilmm6qir.MomentFailure => 'MomentFailure',
      _ievswv9n.MoodFailure => 'MoodFailure',
      _i3uwx2a4.MoodState => 'MoodState',
      _ium95mnn.PairingFailure => 'PairingFailure',
      _iyyqlhox.PairingState => 'PairingState',
      _i9648dgo.PushFailure => 'PushFailure',
      _ipb0000r.ReminderEntry => 'ReminderEntry',
      _ishkpy03.ReminderFailure => 'ReminderFailure',
      _ipjphtkx.ScheduleFailure => 'ScheduleFailure',
      _icmbt5hs.WidgetDeliveryState => 'WidgetDeliveryState',
      _iv63qsae.WidgetDeviceCredential => 'WidgetDeviceCredential',
      _iro0jbgj.WidgetScheduleEntry => 'WidgetScheduleEntry',
      _iezshfmm.WidgetSendReceipt => 'WidgetSendReceipt',
      _i8hd5s9w.WidgetTimeline => 'WidgetTimeline',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('closecall.', '');
    }

    switch (data) {
      case _ib26upii.AccountState():
        return 'AccountState';
      case _ijjfwapm.MediaAsset():
        return 'MediaAsset';
      case _iuzipihh.MediaFailure():
        return 'MediaFailure';
      case _iq4regyx.MomentEntry():
        return 'MomentEntry';
      case _ilmm6qir.MomentFailure():
        return 'MomentFailure';
      case _ievswv9n.MoodFailure():
        return 'MoodFailure';
      case _i3uwx2a4.MoodState():
        return 'MoodState';
      case _ium95mnn.PairingFailure():
        return 'PairingFailure';
      case _iyyqlhox.PairingState():
        return 'PairingState';
      case _i9648dgo.PushFailure():
        return 'PushFailure';
      case _ipb0000r.ReminderEntry():
        return 'ReminderEntry';
      case _ishkpy03.ReminderFailure():
        return 'ReminderFailure';
      case _ipjphtkx.ScheduleFailure():
        return 'ScheduleFailure';
      case _icmbt5hs.WidgetDeliveryState():
        return 'WidgetDeliveryState';
      case _iv63qsae.WidgetDeviceCredential():
        return 'WidgetDeviceCredential';
      case _iro0jbgj.WidgetScheduleEntry():
        return 'WidgetScheduleEntry';
      case _iezshfmm.WidgetSendReceipt():
        return 'WidgetSendReceipt';
      case _i8hd5s9w.WidgetTimeline():
        return 'WidgetTimeline';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AccountState') {
      return deserialize<_ib26upii.AccountState>(data['data']);
    }
    if (dataClassName == 'MediaAsset') {
      return deserialize<_ijjfwapm.MediaAsset>(data['data']);
    }
    if (dataClassName == 'MediaFailure') {
      return deserialize<_iuzipihh.MediaFailure>(data['data']);
    }
    if (dataClassName == 'MomentEntry') {
      return deserialize<_iq4regyx.MomentEntry>(data['data']);
    }
    if (dataClassName == 'MomentFailure') {
      return deserialize<_ilmm6qir.MomentFailure>(data['data']);
    }
    if (dataClassName == 'MoodFailure') {
      return deserialize<_ievswv9n.MoodFailure>(data['data']);
    }
    if (dataClassName == 'MoodState') {
      return deserialize<_i3uwx2a4.MoodState>(data['data']);
    }
    if (dataClassName == 'PairingFailure') {
      return deserialize<_ium95mnn.PairingFailure>(data['data']);
    }
    if (dataClassName == 'PairingState') {
      return deserialize<_iyyqlhox.PairingState>(data['data']);
    }
    if (dataClassName == 'PushFailure') {
      return deserialize<_i9648dgo.PushFailure>(data['data']);
    }
    if (dataClassName == 'ReminderEntry') {
      return deserialize<_ipb0000r.ReminderEntry>(data['data']);
    }
    if (dataClassName == 'ReminderFailure') {
      return deserialize<_ishkpy03.ReminderFailure>(data['data']);
    }
    if (dataClassName == 'ScheduleFailure') {
      return deserialize<_ipjphtkx.ScheduleFailure>(data['data']);
    }
    if (dataClassName == 'WidgetDeliveryState') {
      return deserialize<_icmbt5hs.WidgetDeliveryState>(data['data']);
    }
    if (dataClassName == 'WidgetDeviceCredential') {
      return deserialize<_iv63qsae.WidgetDeviceCredential>(data['data']);
    }
    if (dataClassName == 'WidgetScheduleEntry') {
      return deserialize<_iro0jbgj.WidgetScheduleEntry>(data['data']);
    }
    if (dataClassName == 'WidgetSendReceipt') {
      return deserialize<_iezshfmm.WidgetSendReceipt>(data['data']);
    }
    if (dataClassName == 'WidgetTimeline') {
      return deserialize<_i8hd5s9w.WidgetTimeline>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacc.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iaic.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iacc.Protocol().registerHostProtocol('closecall', this);
    _iaic.Protocol().registerHostProtocol('closecall', this);
  }

  @override
  String getModuleName() => 'closecall';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
