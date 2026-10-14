import 'package:meta/meta.dart';

/// Categories of warm reminders a couple can set.
enum ReminderKind {
  call('call', 'Call', '📞'),
  dateNight('dateNight', 'Date night', '🌙'),
  birthday('birthday', 'Birthday', '🎂'),
  anniversary('anniversary', 'Anniversary', '💛'),
  event('event', 'Special event', '🎉');

  const ReminderKind(this.key, this.label, this.emoji);

  final String key;
  final String label;
  final String emoji;

  static ReminderKind fromKey(String key) {
    return ReminderKind.values.firstWhere(
      (r) => r.key == key,
      orElse: () => ReminderKind.event,
    );
  }
}

/// A scheduled reminder shared by the couple.
@immutable
class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.kind,
    required DateTime when,
  }) : when = when.toUtc();

  final String id;
  final String title;
  final ReminderKind kind;
  final DateTime when;

  bool isUpcomingAt(DateTime now) => when.isAfter(now.toUtc());

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: ReminderKind.fromKey(json['kind'] as String),
      when: DateTime.parse(json['when'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.key,
    'when': when.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.title == title &&
      other.kind == kind &&
      other.when == when;

  @override
  int get hashCode => Object.hash(id, title, kind, when);
}

/// Returns the soonest reminder strictly after [now], or null if none.
Reminder? nextReminder(List<Reminder> reminders, DateTime now) {
  final upcoming = reminders.where((r) => r.isUpcomingAt(now)).toList()
    ..sort((a, b) => a.when.compareTo(b.when));
  return upcoming.isEmpty ? null : upcoming.first;
}
