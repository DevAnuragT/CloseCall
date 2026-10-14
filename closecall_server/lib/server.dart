import 'src/auth/authentication.dart';
import 'src/generated/serverpod.dart';
import 'src/moments/moment_event_dispatcher.dart';
import 'src/push/fcm_sender.dart';
import 'src/push/push_outbox_dispatcher.dart';
import 'src/reminders/reminder_event_dispatcher.dart';
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
    MomentEventOutboxRuntime.dispatcher = null;
    ReminderEventOutboxRuntime.dispatcher = null;
    return;
  }
  final sender = FcmHttpV1Sender(account);
  final dispatcher = PushOutboxDispatcher(sender: sender);
  final momentDispatcher = MomentEventOutboxDispatcher(sender: sender);
  final reminderDispatcher = ReminderEventOutboxDispatcher(sender: sender);
  PushOutboxRuntime.dispatcher = dispatcher;
  MomentEventOutboxRuntime.dispatcher = momentDispatcher;
  ReminderEventOutboxRuntime.dispatcher = reminderDispatcher;
  final runner = PushOutboxRunner(dispatcher);
  final momentRunner = MomentEventOutboxRunner(momentDispatcher);
  final reminderRunner = ReminderEventOutboxRunner(reminderDispatcher);
  runner.start(pod);
  momentRunner.start(pod);
  reminderRunner.start(pod);
  pod.experimental.shutdownTasks.addTask(
    'closecall-push-outbox-runner',
    () async {
      runner.stop();
      momentRunner.stop();
      reminderRunner.stop();
      PushOutboxRuntime.dispatcher = null;
      MomentEventOutboxRuntime.dispatcher = null;
      ReminderEventOutboxRuntime.dispatcher = null;
    },
  );
}
