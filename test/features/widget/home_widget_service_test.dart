import 'dart:io';

import 'package:closecall/features/widget/data/home_widget_service.dart';
import 'package:closecall/features/widget/data/native_widget_timeline.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const widget = MethodChannel('home_widget');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('closecall-photo-test-');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
    messenger.setMockMethodCallHandler(widget, (call) async {
      calls.add(call.method);
      if (call.method == 'getWidgetData') return null;
      return true;
    });
    messenger.setMockMethodCallHandler(AndroidWidgetTimeline.channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() async {
    for (final channel in [paths, widget, AndroidWidgetTimeline.channel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
    await directory.delete(recursive: true);
  });

  test(
    'manual photo stops old cache before write and removes owned old files',
    () async {
      final previous = File('${directory.path}/widget_123.png')
        ..writeAsBytesSync(testPng);
      final unrelated = File('${directory.path}/keep.txt')
        ..writeAsStringSync('preserve');
      final path = await HomeWidgetService.setPhoto(testPng);
      expect(calls, ['disableTimeline', 'saveWidgetData', 'updateWidget']);
      expect(await File(path).readAsBytes(), testPng);
      expect(previous.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    },
  );

  test(
    'automatic queued write leaves timeline lifecycle to its controller',
    () async {
      await HomeWidgetService.setPhoto(testPng, preserveTimeline: true);
      expect(calls, ['saveWidgetData', 'updateWidget']);
    },
  );

  test('clear removes cache and only owned standalone photo files', () async {
    final previous = File('${directory.path}/widget_456_1.png')
      ..writeAsBytesSync(testPng);
    final unrelated = File('${directory.path}/another.png')
      ..writeAsBytesSync(testPng);
    await HomeWidgetService.clear();
    expect(calls, [
      'clearTimeline',
      'getWidgetData',
      'saveWidgetData',
      'updateWidget',
    ]);
    expect(previous.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
  });

  test(
    'failed cache disable cannot silently overwrite a manual widget',
    () async {
      messenger.setMockMethodCallHandler(
        AndroidWidgetTimeline.channel,
        (_) async => throw PlatformException(code: 'test-cache-error'),
      );
      await expectLater(
        HomeWidgetService.setPhoto(testPng),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isEmpty);
      expect(directory.listSync(), isEmpty);
    },
  );
}
