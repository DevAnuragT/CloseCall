import 'package:closecall_server/src/widget/widget_schedule_policy.dart';
import 'package:closecall_server/src/widget/widget_timeline_service.dart';
import 'package:test/test.dart';

void main() {
  const key = WidgetSchedulePolicy.environmentKey;

  test('unset defaults to existing development/test durable wake behavior', () {
    expect(
      WidgetSchedulePolicy.fromEnvironment(environment: {}).futureCallsEnabled,
      isTrue,
    );
  });

  test('exact true and false select the policy', () {
    for (final enabled in [true, false]) {
      expect(
        WidgetSchedulePolicy.fromEnvironment(
          environment: {key: enabled.toString()},
        ).futureCallsEnabled,
        enabled,
      );
    }
  });

  for (final invalid in [
    '',
    'TRUE',
    'False',
    '0',
    '1',
    'yes',
    'no',
    ' true',
    'false ',
    'false\n',
  ]) {
    test(
      'invalid flag ${invalid.codeUnits} fails closed without echoing value',
      () {
        expect(
          () =>
              WidgetSchedulePolicy.fromEnvironment(environment: {key: invalid}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              '$key must be exactly true or false.',
            ),
          ),
        );
      },
    );
  }

  test('explicit service policies do not share mutable state', () {
    final disabled = const WidgetSchedulePolicy(futureCallsEnabled: false);
    final enabled = const WidgetSchedulePolicy();
    expect(() => WidgetTimelineService(policy: disabled), returnsNormally);
    expect(() => WidgetTimelineService(policy: enabled), returnsNormally);
    expect(disabled.futureCallsEnabled, isFalse);
    expect(enabled.futureCallsEnabled, isTrue);
  });
}
