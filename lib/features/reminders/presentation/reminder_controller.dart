import 'dart:async';

import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../pairing/presentation/pairing_controller.dart';
import '../data/reminder_notifications.dart';
import '../data/reminders_repository.dart';

const reminderKinds = <String>[
  'call',
  'dateNight',
  'birthday',
  'anniversary',
  'event',
];

class ReminderValidationException implements Exception {
  const ReminderValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns reminder state for one authenticated, paired scope.
class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.pairing,
    required this.repository,
    ReminderNotifications? notifications,
    DateTime Function()? now,
    Uuid? uuid,
  }) : notifications = notifications ?? const NoopReminderNotifications(),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PairingController pairing;
  final RemindersRepository repository;
  final ReminderNotifications notifications;
  final DateTime Function() _now;
  final Uuid _uuid;

  List<api.ReminderEntry> reminders = const [];
  Object? error;
  bool loading = false;
  bool saving = false;
  bool get activeLimitReached => activeReminders.length >= maxActive;
  List<api.ReminderEntry> get activeReminders => reminders
      .where((reminder) => reminder.completedAt == null)
      .toList(growable: false);
  List<api.ReminderEntry> get completedReminders => reminders
      .where((reminder) => reminder.completedAt != null)
      .toList(growable: false);

  static const maxActive = 100;
  static const _pollInterval = Duration(seconds: 30);
  static const _automaticRetryDelays = <Duration>[
    Duration(milliseconds: 200),
    Duration(milliseconds: 500),
  ];

  Timer? _pollTimer;
  bool _started = false;
  bool _disposed = false;
  bool _foreground = false;
  int _revision = 0;
  String? _scopeUser;
  String? _scopeCouple;
  int _scopeAuthRevision = -1;
  Future<void> Function()? _retry;
  bool get paired => pairing.couple?.isComplete == true;
  bool get canUse => paired && pairing.userId != null;
  bool get hasExplicitRetry => _retry != null;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    pairing.addListener(_pairingChanged);
    pairing.addBeforeSignOutHook(_clearScopedNotifications);
    _pairingChanged();
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_foreground && canUse) unawaited(refresh(automatic: true));
  }

  void _pairingChanged() {
    if (!_started || _disposed) return;
    final user = pairing.userId;
    final couple = pairing.couple;
    final nextUser = user != null && couple?.isComplete == true ? user : null;
    final nextCouple = nextUser == null ? null : couple!.id;
    final changed =
        nextUser != _scopeUser ||
        nextCouple != _scopeCouple ||
        pairing.authRevision != _scopeAuthRevision;
    if (!changed) return;
    final hadScope = _scopeUser != null;
    _scopeUser = nextUser;
    _scopeCouple = nextCouple;
    _scopeAuthRevision = nextUser == null ? -1 : pairing.authRevision;
    _revision++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _retry = null;
    error = null;
    reminders = const [];
    if (nextUser == null) {
      if (hadScope) unawaited(notifications.cancelAll());
      loading = false;
      saving = false;
      notifyListeners();
      return;
    }
    notifyListeners();
    unawaited(refresh(automatic: true));
  }

  bool _inScope(String user, String couple, int authRevision) =>
      !_disposed &&
      pairing.userId == user &&
      pairing.couple?.id == couple &&
      pairing.couple?.isComplete == true &&
      pairing.authRevision == authRevision &&
      _scopeUser == user &&
      _scopeCouple == couple &&
      _scopeAuthRevision == authRevision;

  Future<void> refresh({bool automatic = false}) async {
    if (_disposed || !canUse || loading || saving) return;
    final user = _scopeUser;
    final couple = _scopeCouple;
    final authRevision = _scopeAuthRevision;
    if (user == null || couple == null) return;
    final revision = ++_revision;
    loading = true;
    if (!automatic) error = null;
    notifyListeners();
    final attempts = automatic ? _automaticRetryDelays.length + 1 : 1;
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (!_inScope(user, couple, authRevision) || revision != _revision) {
          return;
        }
        try {
          final result = await repository.listReminders();
          if (!_inScope(user, couple, authRevision) || revision != _revision) {
            return;
          }
          reminders = List.unmodifiable(result);
          _retry = null;
          await _syncNotifications(result);
          return;
        } catch (failure) {
          if (attempt + 1 == attempts) {
            if (_inScope(user, couple, authRevision) && revision == _revision) {
              error = failure;
              _retry = () => refresh();
            }
            return;
          }
          await Future<void>.delayed(_automaticRetryDelays[attempt]);
        }
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
        if (_foreground && canUse) _schedulePoll();
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_disposed || !_foreground || !canUse || loading || saving) return;
    _pollTimer = Timer(_pollInterval, () {
      _pollTimer = null;
      unawaited(refresh(automatic: true));
    });
  }

  Future<void> _syncNotifications(List<api.ReminderEntry> entries) async {
    for (final reminder in entries) {
      if (_disposed) return;
      if (reminder.completedAt == null && reminder.remindAt.isAfter(_now())) {
        await notifications.schedule(reminder);
      } else {
        await notifications.cancel(reminder);
      }
    }
  }

  Future<bool> create({
    required String title,
    required String kind,
    required DateTime remindAt,
  }) async {
    final user = _scopeUser;
    final couple = _scopeCouple;
    final authRevision = _scopeAuthRevision;
    _validate(title: title, kind: kind, remindAt: remindAt);
    if (user == null ||
        couple == null ||
        !_inScope(user, couple, authRevision)) {
      throw const ReminderValidationException(
        'Pair before creating reminders.',
      );
    }
    if (activeLimitReached) {
      throw const ReminderValidationException(
        'You can have at most 100 active reminders.',
      );
    }
    final requestId = _uuid.v4();
    Future<bool> action() async {
      if (!_inScope(user, couple, authRevision)) return false;
      final created = await repository.createReminder(
        requestId: requestId,
        title: title.trim(),
        kind: kind,
        remindAt: remindAt.toUtc(),
      );
      if (!_inScope(user, couple, authRevision)) return false;
      reminders = List.unmodifiable([created, ...reminders]);
      _retry = null;
      await notifications.schedule(created);
      return true;
    }

    return _mutate(action);
  }

  Future<bool> retry() async {
    final action = _retry;
    if (action == null) return false;
    await action();
    return true;
  }

  Future<bool> complete(api.ReminderEntry reminder) async {
    final id = reminder.id.toString();
    return _mutate(() async {
      if (!canUse) return false;
      await repository.completeReminder(reminderId: id);
      await notifications.cancel(reminder);
      await refresh();
      return true;
    });
  }

  Future<bool> delete(api.ReminderEntry reminder) async {
    final id = reminder.id.toString();
    return _mutate(() async {
      if (!canUse) return false;
      await repository.deleteReminder(reminderId: id);
      await notifications.cancel(reminder);
      reminders = List.unmodifiable(
        reminders.where((item) => item.id.toString() != id),
      );
      return true;
    });
  }

  Future<bool> _mutate(Future<bool> Function() action) async {
    if (_disposed || loading || saving) return false;
    saving = true;
    error = null;
    _retry = action;
    notifyListeners();
    try {
      final result = await action();
      if (result) _retry = null;
      return result;
    } catch (failure) {
      if (!_disposed) error = failure;
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
        if (_foreground) _schedulePoll();
      }
    }
  }

  void _validate({
    required String title,
    required String kind,
    required DateTime remindAt,
  }) {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 120) {
      throw const ReminderValidationException(
        'Title must be 1–120 characters.',
      );
    }
    if (!reminderKinds.contains(kind)) {
      throw const ReminderValidationException(
        'Choose a valid reminder category.',
      );
    }
    final delta = remindAt.toUtc().difference(_now().toUtc());
    if (delta < const Duration(minutes: 1)) {
      throw const ReminderValidationException(
        'Choose a time at least one minute from now.',
      );
    }
    if (delta > const Duration(days: 366)) {
      throw const ReminderValidationException('Choose a time within 366 days.');
    }
  }

  Future<void> _clearScopedNotifications() async {
    await notifications.cancelAll();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _pollTimer?.cancel();
    if (_started) {
      pairing.removeListener(_pairingChanged);
      pairing.removeBeforeSignOutHook(_clearScopedNotifications);
      unawaited(notifications.cancelAll());
    }
    super.dispose();
  }
}
