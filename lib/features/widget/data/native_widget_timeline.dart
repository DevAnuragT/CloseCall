import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// No credentials or network access cross this bridge. Calls must use the
/// shared LocalWidgetWriter queue, including identity cleanup.
abstract interface class NativeWidgetTimeline {
  bool get supported;
  Future<void> cacheTimeline(Map<String, Object?> payload);
  Future<void> disableTimeline();
  Future<void> clearTimeline();
}

class AndroidWidgetTimeline implements NativeWidgetTimeline {
  const AndroidWidgetTimeline();
  static const channel = MethodChannel('closecall/widget_timeline');
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> cacheTimeline(Map<String, Object?> payload) async {
    if (supported) await channel.invokeMethod<void>('cacheTimeline', payload);
  }

  @override
  Future<void> disableTimeline() async {
    if (supported) await channel.invokeMethod<void>('disableTimeline');
  }

  @override
  Future<void> clearTimeline() async {
    if (supported) await channel.invokeMethod<void>('clearTimeline');
  }
}

/// Default for injected writers: tests never invoke plugins implicitly.
class ForegroundWidgetTimeline implements NativeWidgetTimeline {
  const ForegroundWidgetTimeline();
  @override
  bool get supported => false;
  @override
  Future<void> cacheTimeline(Map<String, Object?> payload) async {}
  @override
  Future<void> disableTimeline() async {}
  @override
  Future<void> clearTimeline() async {}
}

/// Take an owned byte snapshot before adding a payload to the native queue.
Map<String, Object?> copyTimelinePayload(Map<String, Object?> payload) => {
  ...payload,
  'schedules': [
    for (final entry in payload['schedules'] as List)
      Map<String, Object?>.from(entry as Map),
  ],
  'photos': {
    for (final entry in (payload['photos'] as Map<String, Uint8List>).entries)
      entry.key: Uint8List.fromList(entry.value),
  },
};
