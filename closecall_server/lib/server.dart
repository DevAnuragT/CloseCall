import 'src/auth/authentication.dart';
import 'src/generated/serverpod.dart';
import 'src/push/fcm_sender.dart';
import 'src/push/push_outbox_dispatcher.dart';
import 'src/widget/widget_schedule_policy.dart';

/// Starts the API with JWT authentication and persistent PostgreSQL storage.
Future<void> run(List<String> args) async {
  // Validate before constructing/starting the pod, without logging environment
  // values. The endpoint services independently capture the same runtime policy.
  final policy = WidgetSchedulePolicy.fromEnvironment();
  final account = FcmServiceAccount.tryFromEnvironment();
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

  // Starter has no durable future-call guarantee for this workload. FCM
  // events are persisted in the send transaction and this bounded, leased
  // runner is only their best-effort wake-up/reconciliation mechanism.
  if (account == null) {
    PushOutboxRuntime.dispatcher = null;
    return;
  }
  final dispatcher = PushOutboxDispatcher(sender: FcmHttpV1Sender(account));
  PushOutboxRuntime.dispatcher = dispatcher;
  final runner = PushOutboxRunner(dispatcher);
  runner.start(pod);
  pod.experimental.shutdownTasks.addTask(
    'closecall-push-outbox-runner',
    () async {
      runner.stop();
      PushOutboxRuntime.dispatcher = null;
    },
  );
}
