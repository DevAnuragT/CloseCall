import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/presentation/media_controller.dart';
import '../data/schedule_repository.dart';
import 'schedule_controller.dart';
import 'widget_ui_components.dart';

/// Server schedules target the partner; fallback and auto-sync target oneself.
class SchedulePanel extends StatefulWidget {
  const SchedulePanel({
    super.key,
    required this.controller,
    required this.media,
  });
  final ScheduleController controller;
  final MediaController media;
  @override
  State<SchedulePanel> createState() => _SchedulePanelState();
}

class _SchedulePanelState extends State<SchedulePanel> {
  late final _start = TextEditingController(
    text: widget.controller.serverNow
        .add(const Duration(minutes: 5))
        .toIso8601String(),
  );
  late final _end = TextEditingController(
    text: widget.controller.serverNow
        .add(const Duration(hours: 1))
        .toIso8601String(),
  );
  String? _scheduleAsset;
  String? _fallbackAsset;
  String? _formError;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  DateTime _parse(String text) {
    final value = text.trim();
    if (!RegExp(
      r'(Z|[+-]\d{2}:\d{2})$',
      caseSensitive: false,
    ).hasMatch(value)) {
      throw const FormatException(
        'Include an explicit time zone: Z or ±hh:mm.',
      );
    }
    return DateTime.parse(value).toUtc();
  }

  Future<void> _create(String? asset) async {
    try {
      if (asset == null) {
        throw const FormatException(
          'Select one of your uploaded private photos.',
        );
      }
      final from = _parse(_start.text);
      final until = _parse(_end.text);
      setState(() => _formError = null);
      await widget.controller.createPartnerSchedule(asset, from, until);
    } on FormatException catch (failure) {
      if (mounted) setState(() => _formError = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.media]),
    builder: (context, _) {
      final c = widget.controller;
      final all = widget.media.assets
          .where((a) => a.coupleId == c.pairing.couple?.id)
          .toList();
      final uploaded = all
          .where((a) => a.uploaderId == c.pairing.userId)
          .toList();
      final scheduleAsset = uploaded.any((a) => a.assetId == _scheduleAsset)
          ? _scheduleAsset
          : null;
      final fallbackAsset = all.any((a) => a.assetId == _fallbackAsset)
          ? _fallbackAsset
          : null;
      final disabled = !c.canSchedule || c.busy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WidgetCard(
            eyebrow: 'Private timelines',
            title: 'Let the right photo arrive at the right time',
            icon: Icons.schedule_rounded,
            accent: AppColors.plum,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A schedule sends a private photo to your partner. Their device chooses whether to sync it.',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      title: Text(
                        c.backgroundCacheSupported
                            ? 'Auto-sync + cached Android transitions'
                            : 'Foreground auto-sync on this device',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Opt-in for this account/couple only. Local-only photo choices pause it. '
                        '${c.backgroundCacheSupported ? 'Cached Android transitions may run while app closed; OS can delay. New, changed or cancelled schedules require reconnect; cache expires after 24h.' : 'Background cache is unavailable on this platform; keep the app open.'}',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          height: 1.3,
                        ),
                      ),
                      value: c.autoSyncEnabled,
                      onChanged: c.canSchedule ? c.setAutoSync : null,
                    ),
                  ),
                ),
                if (!c.canSchedule) ...[
                  const SizedBox(height: AppSpacing.md),
                  const WidgetStatusCard(
                    message: 'Complete pairing before loading timelines.',
                    icon: Icons.people_outline_rounded,
                    color: AppColors.warning,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Server-adjusted now: ${c.serverNow.toUtc().toIso8601String()}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: disabled ? null : c.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh timelines'),
                ),
                if (c.busy) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: const LinearProgressIndicator(minHeight: 5),
                  ),
                ],
                if (c.syncing)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'Downloading/applying your own timeline…',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                ..._operationMessages(c, disabled),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          WidgetCard(
            eyebrow: 'For your partner',
            title: 'Schedule a private photo',
            icon: Icons.favorite_outline_rounded,
            accent: AppColors.blush,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (uploaded.isEmpty)
                  const WidgetEmptyState(
                    title: 'Upload your own photo first',
                    message:
                        'Your uploaded private photos will be available here to schedule.',
                    icon: Icons.cloud_upload_outlined,
                  ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('schedule-asset'),
                  isExpanded: true,
                  initialValue: scheduleAsset,
                  hint: const Text('Your uploaded private photo'),
                  decoration: _fieldDecoration('Photo to send'),
                  items: [
                    for (final a in uploaded)
                      DropdownMenuItem(
                        value: a.assetId,
                        child: Text(a.assetId, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: disabled || c.pendingCreate != null
                      ? null
                      : (value) => setState(() => _scheduleAsset = value),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('schedule-start'),
                  controller: _start,
                  enabled: !disabled && c.pendingCreate == null,
                  decoration: _fieldDecoration(
                    'Start — ISO 8601 with Z or ±hh:mm',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('schedule-end'),
                  controller: _end,
                  enabled: !disabled && c.pendingCreate == null,
                  decoration: _fieldDecoration(
                    'End — ISO 8601 with Z or ±hh:mm',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Times are absolute UTC instants; overlaps use newest-created priority and revert afterward.',
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  WidgetStatusCard(
                    key: const Key('schedule-form-error'),
                    message: _formError!,
                    icon: Icons.error_outline_rounded,
                    color: AppColors.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: disabled || c.pendingCreate != null
                        ? null
                        : () => _create(scheduleAsset),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Schedule for partner'),
                  ),
                ),
                if (c.pendingCreate != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  WidgetStatusCard(
                    message:
                        'Pending request: ${c.pendingCreate!.requestId}. Retry preserves this exact photo and UTC window.',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    action: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: c.busy ? null : c.retryCreate,
                          child: const Text('Retry pending schedule'),
                        ),
                        TextButton(
                          onPressed: c.discardPendingCreate,
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
            eyebrow: 'This device',
            title: 'Choose your own fallback',
            icon: Icons.phone_android_rounded,
            accent: AppColors.clay,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your own fallback — not your partner’s',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('fallback-asset'),
                  isExpanded: true,
                  initialValue: fallbackAsset,
                  hint: const Text('Choose a private fallback photo'),
                  decoration: _fieldDecoration('Fallback photo'),
                  items: [
                    for (final a in all)
                      DropdownMenuItem(
                        value: a.assetId,
                        child: Text(a.assetId, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: disabled
                      ? null
                      : (value) => setState(() => _fallbackAsset = value),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: disabled || fallbackAsset == null
                      ? null
                      : () => c.setOwnFallback(fallbackAsset),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save my own fallback'),
                ),
              ],
            ),
          ),
          ..._timeline(c, c.ownTimeline, own: true),
          ..._timeline(c, c.partnerTimeline, own: false),
        ],
      );
    },
  );

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.paper,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: AppColors.plum.withValues(alpha: 0.14)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: AppColors.plum.withValues(alpha: 0.14)),
    ),
  );

  List<Widget> _operationMessages(ScheduleController c, bool disabled) => [
    if (c.error != null)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: WidgetStatusCard(
          key: const Key('schedule-error'),
          message: scheduleErrorMessage(c.error!),
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          action: TextButton(
            onPressed: c.busy ? null : c.retry,
            child: const Text('Retry schedule operation'),
          ),
        ),
      ),
    if (c.streamError != null)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: WidgetStatusCard(
          message: 'Live timeline: ${scheduleErrorMessage(c.streamError!)}',
          icon: Icons.wifi_off_rounded,
          color: AppColors.warning,
          action: TextButton(
            onPressed: disabled ? null : c.refresh,
            child: const Text('Reconnect timeline stream'),
          ),
        ),
      ),
    if (c.syncError != null)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: WidgetStatusCard(
          message: 'Timeline sync: ${c.syncError}',
          icon: Icons.sync_problem_rounded,
          color: AppColors.error,
          action: TextButton(
            onPressed: c.autoSyncEnabled && !c.syncing ? c.syncNow : null,
            child: const Text('Retry timeline sync'),
          ),
        ),
      ),
    if (c.status != null)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: WidgetStatusCard(
          message: c.status!,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
      ),
  ];

  List<Widget> _timeline(
    ScheduleController c,
    WidgetTimeline? timeline, {
    required bool own,
  }) {
    final current = own ? c.ownCurrentAssetId : c.partnerCurrentAssetId;
    final entries = [...?timeline?.schedules]
      ..sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
    return [
      const SizedBox(height: AppSpacing.md),
      WidgetCard(
        eyebrow: own ? 'Your device' : 'Partner’s device',
        title: own ? 'Your received timeline' : 'Partner’s received timeline',
        icon: own ? Icons.phone_android_rounded : Icons.favorite_border_rounded,
        accent: own ? AppColors.clay : AppColors.blush,
        child: timeline == null
            ? const WidgetEmptyState(
                title: 'Timeline not loaded',
                message: 'Refresh to check for the latest private schedule.',
                icon: Icons.hourglass_empty_rounded,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimelineMeta(
                    recipient: timeline.recipientId,
                    current: current,
                    fallback: timeline.fallbackAssetId,
                    next: (own ? c.ownResolution : c.partnerResolution)
                        ?.nextTransition,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (entries.isEmpty)
                    const WidgetEmptyState(
                      title: 'No scheduled windows',
                      message: 'The fallback photo stays in place for now.',
                      icon: Icons.event_available_outlined,
                    ),
                  for (final entry in entries)
                    _ScheduleEntryTile(
                      entry: entry,
                      canCancel: c.canCancel(entry),
                      enabled: !c.busy,
                      onCancel: () => c.cancelSchedule(entry),
                    ),
                ],
              ),
      ),
    ];
  }
}

class _TimelineMeta extends StatelessWidget {
  const _TimelineMeta({
    required this.recipient,
    required this.current,
    required this.fallback,
    required this.next,
  });

  final String recipient;
  final String? current;
  final String? fallback;
  final DateTime? next;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaLine(label: 'Recipient', value: recipient),
        _MetaLine(label: 'Current photo', value: current ?? 'None'),
        _MetaLine(label: 'Fallback', value: fallback ?? 'None'),
        _MetaLine(
          label: 'Next transition (UTC)',
          value: next?.toIso8601String() ?? 'None',
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEntryTile extends StatelessWidget {
  const _ScheduleEntryTile({
    required this.entry,
    required this.canCancel,
    required this.enabled,
    required this.onCancel,
  });

  final WidgetScheduleEntry entry;
  final bool canCancel;
  final bool enabled;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_outlined, color: AppColors.clay, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo ${entry.assetId}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.activeFrom.toUtc().toIso8601String()} → ${entry.activeUntil.toUtc().toIso8601String()}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                Text(
                  'Local: ${entry.activeFrom.toLocal()} → ${entry.activeUntil.toLocal()}',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (canCancel)
            IconButton(
              key: Key('cancel-schedule-${entry.scheduleId}'),
              tooltip: 'Cancel schedule',
              onPressed: enabled ? onCancel : null,
              icon: const Icon(Icons.cancel_outlined),
            ),
        ],
      ),
    );
  }
}
