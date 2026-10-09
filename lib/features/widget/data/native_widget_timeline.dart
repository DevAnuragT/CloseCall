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

/// Optional, deliberately separate from timeline fakes and other platforms.
/// Flutter validates secure identity/membership before calling restoreScope.
abstract interface class ScopedWidgetRestoration {
  Future<void> suspendForStartup();
  Future<RestoredWidgetPhoto?> restoreScope(
    String scope, {
    required bool allowPartnerPhoto,
  });
  Future<void> recordPhotoOwner(String scope, {String? assetId});
}

class RestoredWidgetPhoto {
  const RestoredWidgetPhoto({this.assetId, required this.bytes});
  final String? assetId;
  final Uint8List bytes;
}

class AndroidWidgetTimeline
    implements NativeWidgetTimeline, ScopedWidgetRestoration {
  const AndroidWidgetTimeline();
  static const channel = MethodChannel('closecall/widget_timeline');

  /// The URL is non-secret configuration. Persist it in native preferences so
  /// the manifest FCM receiver can reach the limited background endpoints
  /// without restoring a Flutter user session.
  static Future<void> configureBackgroundServerUrl(String url) async {
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) return;
    await channel.invokeMethod<void>(
      'configureBackgroundServerUrl',
      {'url': url},
    );
  }
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

  @override
  Future<void> suspendForStartup() async {
    if (supported) await channel.invokeMethod<void>('suspendForStartup');
  }

  @override
  Future<RestoredWidgetPhoto?> restoreScope(
    String scope, {
    required bool allowPartnerPhoto,
  }) async {
    if (!supported) return null;
    final result = await channel.invokeMapMethod<String, Object?>(
      'restoreScope',
      {'scope': scope, 'allowPartnerPhoto': allowPartnerPhoto},
    );
    final bytes = result?['bytes'];
    if (bytes is! Uint8List) return null;
    return RestoredWidgetPhoto(
      assetId: result?['assetId'] as String?,
      bytes: bytes,
    );
  }

  @override
  Future<void> recordPhotoOwner(String scope, {String? assetId}) async {
    if (supported) {
      await channel.invokeMethod<void>('recordPhotoOwner', {
        'scope': scope,
        'assetId': assetId,
      });
    }
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
