import 'dart:io';
import 'dart:typed_data';

import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

/// Bridges Flutter to the native Android home-screen widget
/// ([CloseCallWidgetProvider]). Writes the photo to a file the widget can read
/// and asks Android to redraw.
abstract final class HomeWidgetService {
  static const _providerName = 'CloseCallWidgetProvider';
  static const _imageKey = 'widget_image_path';

  /// Writes [pngBytes] to disk and pushes it to the home-screen widget.
  /// Returns the saved file path. A unique filename each time sidesteps the
  /// launcher's bitmap caching so the new photo actually appears.
  static Future<String> setPhoto(Uint8List pngBytes) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}/widget_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);

    await HomeWidget.saveWidgetData<String>(_imageKey, file.path);
    await HomeWidget.updateWidget(
      name: _providerName,
      androidName: _providerName,
    );
    return file.path;
  }

  /// Clears the widget photo (reverts to the empty/fallback state).
  static Future<void> clear() async {
    await HomeWidget.saveWidgetData<String>(_imageKey, null);
    await HomeWidget.updateWidget(
      name: _providerName,
      androidName: _providerName,
    );
  }
}
