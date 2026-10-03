import 'dart:io';
import 'dart:typed_data';

import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'native_widget_timeline.dart';

/// Bridges Flutter to the native Android home-screen widget
/// ([CloseCallWidgetProvider]). Writes the photo to a file the widget can read
/// and asks Android to redraw.
abstract final class HomeWidgetService {
  static const _providerName = 'CloseCallWidgetProvider';
  static const _imageKey = 'widget_image_path';
  static int _sequence = 0;

  /// Writes [pngBytes] to disk and pushes it to the home-screen widget.
  /// Returns the saved file path. A unique filename each time sidesteps the
  /// launcher's bitmap caching so the new photo actually appears.
  static Future<String> setPhoto(
    Uint8List pngBytes, {
    bool preserveTimeline = false,
  }) async {
    // Demo/manual choices must stop a persisted cache from a previous live
    // process too. Automatic writes use the shared timeline writer queue.
    if (!preserveTimeline) {
      await const AndroidWidgetTimeline().disableTimeline();
    }
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}/widget_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);

    await HomeWidget.saveWidgetData<String>(_imageKey, file.path);
    await HomeWidget.updateWidget(
      name: _providerName,
      androidName: _providerName,
    );
    await _removeOldPhotos(dir, keep: file.path);
    return file.path;
  }

  /// Clears the widget photo (reverts to the empty/fallback state).
  static Future<void> clear() async {
    await const AndroidWidgetTimeline().clearTimeline();
    await HomeWidget.saveWidgetData<String>(_imageKey, null);
    await HomeWidget.updateWidget(
      name: _providerName,
      androidName: _providerName,
    );
    await _removeOldPhotos(await getApplicationSupportDirectory());
  }

  static Future<void> _removeOldPhotos(
    Directory directory, {
    String? keep,
  }) async {
    final owned = RegExp(r'^widget_\d+(?:_\d+)?\.png$');
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          entry.path != keep &&
          owned.hasMatch(entry.uri.pathSegments.last)) {
        await entry.delete();
      }
    }
  }
}
