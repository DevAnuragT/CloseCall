import 'dart:io';

/// Runtime feature policy, captured once per service rather than mutable global
/// state. Disabling durable wakes does not disable DB-backed schedules, watchers,
/// or the client's cached transitions.
class WidgetSchedulePolicy {
  static const environmentKey = 'CLOSECALL_FUTURE_CALLS_ENABLED';

  final bool futureCallsEnabled;

  const WidgetSchedulePolicy({this.futureCallsEnabled = true});

  /// Unset preserves the existing local development/test behavior. Cloud
  /// Starter deployments must explicitly set this flag to `false`.
  ///
  /// Only exact `true`/`false` values are accepted. Typos never silently enable
  /// durable wakes, and the error does not expose any environment values.
  factory WidgetSchedulePolicy.fromEnvironment({
    Map<String, String>? environment,
  }) {
    final value = (environment ?? Platform.environment)[environmentKey];
    return switch (value) {
      null || 'true' => const WidgetSchedulePolicy(),
      'false' => const WidgetSchedulePolicy(futureCallsEnabled: false),
      _ => throw StateError('$environmentKey must be exactly true or false.'),
    };
  }
}
