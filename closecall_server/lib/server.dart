import 'src/auth/authentication.dart';
import 'src/generated/serverpod.dart';
import 'src/widget/widget_schedule_policy.dart';

/// Starts the API with JWT authentication and persistent PostgreSQL storage.
Future<void> run(List<String> args) async {
  // Validate before constructing/starting the pod, without logging environment
  // values. The endpoint services independently capture the same runtime policy.
  final policy = WidgetSchedulePolicy.fromEnvironment();
  final pod = Serverpod(
    args,
    configOverride: (config) => policy.futureCallsEnabled
        ? config
        : config.copyWith(
            futureCall: FutureCallConfig(
              enabled: false,
              concurrencyLimit: config.futureCall.concurrencyLimit,
              scanInterval: config.futureCall.scanInterval,
              checkBrokenCalls: config.futureCall.checkBrokenCalls,
              deleteBrokenCalls: config.futureCall.deleteBrokenCalls,
            ),
          ),
  );
  configureAuthentication(pod);
  await pod.start();
}
