import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/presentation/media_controller.dart';
import '../../media/presentation/private_photo_widgets.dart';
import 'schedule_controller.dart';
import 'widget_ui_components.dart';

/// A route is tied to the identity, reauthentication and couple membership that
/// opened it. Never apply an old form to a new account or pairing.
String scheduleAccountScope(ScheduleController controller) {
  final p = controller.pairing;
  final members = [...?p.couple?.memberIds]..sort();
  return '${p.userId}/${p.authRevision}/${p.couple?.id}/'
      '${members.join('/')}';
}

String friendlyScheduleError(Object error) {
  if (error is ScheduleFailure) {
    return switch (error.code) {
      'not_paired' => 'Complete pairing before scheduling a photo.',
      'asset_not_found' =>
        'That photo is no longer available. Choose another photo.',
      'invalid_window' => 'Choose an end after the start, within seven days.',
      'invalid_request_id' || 'request_conflict' =>
        'This schedule could not be confirmed. Discard it before starting again.',
      'schedule_not_found' => 'That schedule is no longer available.',
      'quota_exceeded' =>
        'You have too many schedules. Cancel one before adding another.',
      _ => 'Could not confirm the change. Check your connection and try again.',
    };
  }
  return 'Could not confirm the change. Check your connection and try again.';
}

String localScheduleTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final strings = MaterialLocalizations.of(context);
  return '${strings.formatMediumDate(local)}, '
      '${strings.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class SchedulePanel extends StatefulWidget {
  const SchedulePanel({
    super.key,
    required this.controller,
    required this.media,
    this.showPartnerUpdatesControl = true,
  });
  final ScheduleController controller;
  final MediaController media;
  // Kept for source compatibility. Receiving preferences belong in My widget.
  final bool showPartnerUpdatesControl;
  @override
  State<SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends State<SchedulePanel> {
  late final String _scope = scheduleAccountScope(widget.controller);
  late DateTime _start = widget.controller.serverNow
      .add(const Duration(minutes: 5))
      .toLocal();
  late DateTime _end = _start.add(const Duration(hours: 1));
  String? _assetId;
  String? _message;
  String? _formError;
  bool get _current =>
      mounted &&
      _scope == scheduleAccountScope(widget.controller) &&
      widget.controller.canSchedule;

  Future<void> _pickTime({required bool start}) async {
    final c = widget.controller;
    if (!_current || c.busy || c.pendingCreate != null) return;
    final now = c.serverNow.toLocal();
    final last = start
        ? now.add(const Duration(days: 30))
        : _start.add(const Duration(days: 7));
    if (last.isBefore(now)) {
      setState(() => _formError = 'Choose a new start in the future.');
      return;
    }
    final value = start ? _start : _end;
    final initial = value.isBefore(now)
        ? now
        : value.isAfter(last)
        ? last
        : value;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(last),
      helpText: start ? 'Starts' : 'Ends',
    );
    if (!mounted ||
        date == null ||
        !_current ||
        c.busy ||
        c.pendingCreate != null) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: start ? 'Starts' : 'Ends',
    );
    if (time == null || !_current || c.busy || c.pendingCreate != null) return;
    final chosen = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _message = null;
      _formError = null;
      if (start) {
        _start = chosen;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
        final limit = _start.add(const Duration(days: 7));
        if (_end.isAfter(limit)) _end = limit;
      } else {
        _end = chosen;
      }
      _formError = _windowError();
    });
  }

  String? _windowError() {
    final now = widget.controller.serverNow;
    if (!_end.isAfter(_start)) return 'Choose an end after the start.';
    if (_start.toUtc().isBefore(now)) return 'Choose a start in the future.';
    if (_start.toUtc().isAfter(now.add(const Duration(days: 30)))) {
      return 'Choose a start within the next 30 days.';
    }
    if (_end.difference(_start) > const Duration(days: 7)) {
      return 'A photo can be scheduled for up to seven days.';
    }
    return null;
  }

  Future<void> _create(String? asset) async {
    final c = widget.controller;
    if (!_current || c.busy || c.pendingCreate != null) return;
    final error = asset == null
        ? 'Choose one of your photos first.'
        : _windowError();
    setState(() {
      _formError = error;
      _message = null;
    });
    if (error != null) return;
    await c.createPartnerSchedule(asset!, _start.toUtc(), _end.toUtc());
    if (!_current) return;
    setState(() {
      _formError = c.error == null ? null : friendlyScheduleError(c.error!);
      if (c.pendingCreate == null && c.error == null) {
        _message = 'Photo scheduled for your partner.';
      }
    });
  }

  Future<void> _retryCreate() async {
    final c = widget.controller;
    if (!_current || c.busy || c.pendingCreate == null) return;
    setState(() {
      _formError = null;
      _message = null;
    });
    await c.retryCreate();
    if (!_current) return;
    setState(() {
      _formError = c.error == null ? null : friendlyScheduleError(c.error!);
      if (c.pendingCreate == null && c.error == null) {
        _message = 'Photo scheduled for your partner.';
      }
    });
  }

  Future<void> _cancel(WidgetScheduleEntry entry) async {
    final c = widget.controller;
    if (!_current || c.busy || !c.canCancel(entry)) return;
    setState(() {
      _message = null;
      _formError = null;
    });
    await c.cancelSchedule(entry);
    if (!_current) return;
    setState(() {
      _formError = c.error == null ? null : friendlyScheduleError(c.error!);
      if (c.error == null) _message = 'Schedule cancelled.';
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.media,
      widget.controller.pairing,
      widget.controller.pairing.session,
    ]),
    builder: (context, _) {
      final c = widget.controller;
      if (_scope != scheduleAccountScope(c)) {
        return const WidgetStatusCard(
          message: 'Pairing changed. Close this screen and try again.',
        );
      }
      if (!c.canSchedule) {
        return const WidgetStatusCard(
          message: 'Complete pairing before scheduling a photo.',
        );
      }
      final all = widget.media.assets
          .where((a) => a.coupleId == c.pairing.couple?.id)
          .toList();
      final uploaded = all
          .where((a) => a.uploaderId == c.pairing.userId)
          .toList();
      final pending = c.pendingCreate;
      final selectedId = pending?.assetId ?? _assetId;
      final selected = uploaded
          .where((a) => a.assetId == selectedId)
          .firstOrNull;
      final start = pending?.activeFrom ?? _start;
      final end = pending?.activeUntil ?? _end;
      final disabled = c.busy || pending != null;
      final entries =
          [
              ...?c.ownTimeline?.schedules,
              ...?c.partnerTimeline?.schedules,
            ].where((s) => s.activeUntil.isAfter(c.serverNow)).toList()
            ..sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetCard(
            title: 'Choose a photo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Send a photo to your partner for a little while.'),
                const SizedBox(height: AppSpacing.md),
                if (uploaded.isEmpty)
                  const WidgetEmptyState(
                    title: 'No photos yet',
                    message:
                        'Upload a photo first, then come back to send it later.',
                  )
                else
                  SchedulePhotoGrid(
                    media: widget.media,
                    assets: uploaded,
                    selectedId: selectedId,
                    onChanged: disabled
                        ? null
                        : (asset) => setState(() {
                            _assetId = asset.assetId;
                            _formError = null;
                            _message = null;
                          }),
                  ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  key: const Key('schedule-start'),
                  onPressed: disabled ? null : () => _pickTime(start: true),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Starts\n${localScheduleTime(context, start)}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('schedule-end'),
                  onPressed: disabled ? null : () => _pickTime(start: false),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ends\n${localScheduleTime(context, end)}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (selected != null) ...[
                  SizedBox(
                    height: 100,
                    child: SchedulePrivatePhoto(
                      media: widget.media,
                      asset: selected,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'For your partner\n${localScheduleTime(context, start)} – ${localScheduleTime(context, end)}',
                    key: const Key('schedule-summary'),
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message:
                        'Afterwards, their widget returns to the latest photo you sent, or their default photo.',
                    child: IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.info_outline),
                    ),
                  ),
                ),
                if (_formError != null) ...[
                  WidgetStatusCard(
                    key: const Key('schedule-form-error'),
                    message: _formError!,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_message != null) ...[
                  WidgetStatusCard(
                    message: _message!,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                FilledButton.icon(
                  onPressed: disabled ? null : () => _create(selected?.assetId),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Schedule photo'),
                ),
                if (pending != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  WidgetStatusCard(
                    key: const Key('schedule-error'),
                    message:
                        'This schedule has not been confirmed. Retry keeps the same photo and times.',
                    color: AppColors.warning,
                    action: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: c.busy ? null : _retryCreate,
                          child: const Text('Retry pending schedule'),
                        ),
                        TextButton(
                          onPressed: c.busy
                              ? null
                              : () {
                                  if (!_current) return;
                                  c.discardPendingCreate();
                                  setState(() {
                                    _formError = null;
                                    _message =
                                        'Stopped waiting. The schedule may still have been saved. Check upcoming photos before trying again.';
                                  });
                                },
                          child: const Text('Discard pending schedule'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          WidgetCard(
            child: Material(
              color: AppColors.card,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Upcoming photos'),
                children: [
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('No upcoming photos.'),
                    ),
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 120,
                            child: SchedulePrivatePhoto(
                              media: widget.media,
                              asset: all
                                  .where((a) => a.assetId == entry.assetId)
                                  .firstOrNull,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            entry.recipientId == c.pairing.userId
                                ? 'For you'
                                : 'For your partner',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${localScheduleTime(context, entry.activeFrom)} – ${localScheduleTime(context, entry.activeUntil)}',
                          ),
                          if (c.canCancel(entry))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: Key('cancel-schedule-${entry.scheduleId}'),
                                onPressed: c.busy ? null : () => _cancel(entry),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel'),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Authenticated image choices shared by sending and default selection.
class SchedulePhotoGrid extends StatelessWidget {
  const SchedulePhotoGrid({
    super.key,
    required this.media,
    required this.assets,
    required this.selectedId,
    required this.onChanged,
  });
  final MediaController media;
  final List<MediaAsset> assets;
  final String? selectedId;
  final ValueChanged<MediaAsset>? onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 110).floor().clamp(1, 3);
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < assets.length; i++)
            Semantics(
              label: 'Photo ${i + 1}',
              button: true,
              selected: selectedId == assets[i].assetId,
              enabled: onChanged != null,
              child: SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: InkWell(
                      key: Key('photo-choice-${assets[i].assetId}'),
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(assets[i]),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SchedulePrivatePhoto(media: media, asset: assets[i]),
                          if (selectedId == assets[i].assetId)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(
                                Icons.check_circle,
                                color: AppColors.plum,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// A resolution or identifier is never presented as remotely applied pixels.
class SchedulePrivatePhoto extends StatefulWidget {
  const SchedulePrivatePhoto({
    super.key,
    required this.media,
    required this.asset,
  });
  final MediaController media;
  final MediaAsset? asset;
  @override
  State<SchedulePrivatePhoto> createState() => _SchedulePrivatePhotoState();
}

class _SchedulePrivatePhotoState extends State<SchedulePrivatePhoto> {
  late final String _scope = _currentScope;
  String get _currentScope {
    final p = widget.media.pairing;
    final members = [...?p.couple?.memberIds]..sort();
    return '${p.userId}/${p.authRevision}/${p.couple?.id}/${members.join('/')}';
  }

  bool get _authorized {
    final p = widget.media.pairing;
    return _scope == _currentScope &&
        widget.asset != null &&
        widget.media.canShare &&
        widget.asset!.coupleId == p.couple?.id &&
        p.couple!.memberIds.contains(p.userId) &&
        p.couple!.memberIds.contains(widget.asset!.uploaderId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.media,
    builder: (context, _) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: !_authorized
            ? const ColoredBox(
                color: AppColors.cream,
                child: Center(
                  child: Icon(
                    Icons.photo_outlined,
                    semanticLabel: 'Photo unavailable',
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) => PrivatePhotoPreview(
                  media: widget.media,
                  asset: widget.asset!,
                  fit: BoxFit.cover,
                  compact: true,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
      );
    },
  );
}
