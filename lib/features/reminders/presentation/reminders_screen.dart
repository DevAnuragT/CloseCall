import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/material.dart';

import 'reminder_controller.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({required this.controller, super.key});

  final ReminderController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.activeReminders;
        final completed = controller.completedReminders;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reminders'),
            actions: [
              IconButton(
                key: const ValueKey('reminders-add'),
                onPressed: controller.activeLimitReached
                    ? null
                    : () => _showCreateDialog(context),
                icon: const Icon(Icons.add_alert),
                tooltip: 'Add reminder',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      title: Text(controller.error.toString()),
                      trailing: TextButton(
                        onPressed: controller.retry,
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                if (active.isEmpty && completed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No reminders yet.')),
                  ),
                ...active.map(
                  (reminder) => _ReminderTile(
                    reminder: reminder,
                    onComplete: () => controller.complete(reminder),
                    onDelete: () => controller.delete(reminder),
                  ),
                ),
                if (completed.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 8),
                    child: Text(
                      'Completed',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...completed.map(
                    (reminder) => _ReminderTile(reminder: reminder),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateReminderDialog(controller: controller),
    );
  }
}

/// Owns all transient dialog state. In particular, the text controller is
/// disposed by the dialog route rather than by the caller while a picker or
/// save callback may still be unwinding.
class _CreateReminderDialog extends StatefulWidget {
  const _CreateReminderDialog({required this.controller});

  final ReminderController controller;

  @override
  State<_CreateReminderDialog> createState() => _CreateReminderDialogState();
}

class _CreateReminderDialogState extends State<_CreateReminderDialog> {
  late final TextEditingController _title;
  String _kind = reminderKinds.first;
  DateTime? _selected;
  String? _validation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDate: _selected ?? DateTime.now(),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _selected == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_selected!),
    );
    if (!mounted || time == null) return;
    setState(
      () => _selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _validation = 'Choose a date and time.');
      return;
    }
    setState(() {
      _saving = true;
      _validation = null;
    });
    try {
      final saved = await widget.controller.create(
        title: _title.text,
        kind: _kind,
        remindAt: selected,
      );
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
      } else {
        setState(() => _validation = _errorText());
      }
    } on ReminderValidationException catch (failure) {
      if (mounted) setState(() => _validation = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorText() =>
      widget.controller.error?.toString() ??
      'Could not save reminder. Try again.';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              autofocus: true,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Category'),
              items: reminderKinds
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_kindLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('reminders-date'),
              onPressed: _saving ? null : _chooseDateTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                _selected == null
                    ? 'Choose date and time'
                    : _format(_selected!),
              ),
            ),
            if (_validation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('reminders-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, this.onComplete, this.onDelete});
  final api.ReminderEntry reminder;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = reminder.completedAt != null;
    return Card(
      child: ListTile(
        leading: Icon(completed ? Icons.check_circle : Icons.notifications),
        title: Text(reminder.title),
        subtitle: Text(
          '${_kindLabel(reminder.kind)} • ${_format(reminder.remindAt.toLocal())}',
        ),
        trailing: completed
            ? IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
              )
            : Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check),
                    tooltip: 'Complete',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                  ),
                ],
              ),
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
  'dateNight' => 'Date night',
  'birthday' => 'Birthday',
  'anniversary' => 'Anniversary',
  'call' => 'Call',
  _ => 'Event',
};

String _format(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
