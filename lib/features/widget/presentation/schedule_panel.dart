import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import '../../media/presentation/media_controller.dart';
import '../data/schedule_repository.dart';
import 'schedule_controller.dart';

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
          const Divider(height: 32),
          Text(
            'Photo timelines',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Schedule private photos for your partner. Each recipient must '
            'opt in separately to foreground auto-sync. Nothing runs with the app closed.',
          ),
          if (!c.canSchedule)
            const Text('Complete pairing before loading timelines.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Foreground auto-sync on this device'),
            subtitle: const Text(
              'Opt-in for this account/couple only. Local-only photo choices pause it.',
            ),
            value: c.autoSyncEnabled,
            onChanged: c.canSchedule ? c.setAutoSync : null,
          ),
          Text('Server-adjusted now: ${c.serverNow.toUtc().toIso8601String()}'),
          OutlinedButton(
            onPressed: disabled ? null : c.refresh,
            child: const Text('Refresh timelines'),
          ),
          if (c.busy) const LinearProgressIndicator(),
          if (c.syncing)
            const Text('Downloading/applying own foreground timeline…'),
          if (c.error != null) ...[
            Text(
              scheduleErrorMessage(c.error!),
              key: const Key('schedule-error'),
            ),
            TextButton(
              onPressed: c.busy ? null : c.retry,
              child: const Text('Retry schedule operation'),
            ),
          ],
          if (c.streamError != null) ...[
            Text('Live timeline: ${scheduleErrorMessage(c.streamError!)}'),
            TextButton(
              onPressed: disabled ? null : c.refresh,
              child: const Text('Reconnect timeline stream'),
            ),
          ],
          if (c.syncError != null) ...[
            Text('Foreground sync: ${c.syncError}'),
            TextButton(
              onPressed: c.autoSyncEnabled && !c.syncing ? c.syncNow : null,
              child: const Text('Retry foreground sync'),
            ),
          ],
          if (c.status != null) Text(c.status!),
          const SizedBox(height: 16),
          const Text('Schedule a photo for your partner'),
          if (uploaded.isEmpty)
            const Text(
              'Upload your own private photo above, then select it here.',
            ),
          DropdownButton<String>(
            key: const Key('schedule-asset'),
            isExpanded: true,
            hint: const Text('Your uploaded private photo'),
            value: scheduleAsset,
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
          TextField(
            key: const Key('schedule-start'),
            controller: _start,
            enabled: !disabled && c.pendingCreate == null,
            decoration: const InputDecoration(
              labelText: 'Start — ISO 8601 with Z or ±hh:mm',
            ),
          ),
          TextField(
            key: const Key('schedule-end'),
            controller: _end,
            enabled: !disabled && c.pendingCreate == null,
            decoration: const InputDecoration(
              labelText: 'End — ISO 8601 with Z or ±hh:mm',
            ),
          ),
          const Text(
            'Times are absolute UTC instants; overlaps use newest-created priority and revert afterward.',
          ),
          if (_formError != null)
            Text(_formError!, key: const Key('schedule-form-error')),
          FilledButton(
            onPressed: disabled || c.pendingCreate != null
                ? null
                : () => _create(scheduleAsset),
            child: const Text('Schedule for partner'),
          ),
          if (c.pendingCreate != null) ...[
            Text(
              'Pending request: ${c.pendingCreate!.requestId}. Retry preserves this exact photo and UTC window.',
            ),
            TextButton(
              onPressed: c.busy ? null : c.retryCreate,
              child: const Text('Retry pending schedule'),
            ),
            TextButton(
              onPressed: c.discardPendingCreate,
              child: const Text('Discard pending schedule'),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Your own fallback — not your partner’s'),
          DropdownButton<String>(
            key: const Key('fallback-asset'),
            isExpanded: true,
            hint: const Text('Choose a private fallback photo'),
            value: fallbackAsset,
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
          OutlinedButton(
            onPressed: disabled || fallbackAsset == null
                ? null
                : () => c.setOwnFallback(fallbackAsset),
            child: const Text('Save my own fallback'),
          ),
          ..._timeline(c, c.ownTimeline, own: true),
          ..._timeline(c, c.partnerTimeline, own: false),
        ],
      );
    },
  );

  List<Widget> _timeline(
    ScheduleController c,
    WidgetTimeline? timeline, {
    required bool own,
  }) {
    final current = own ? c.ownCurrentAssetId : c.partnerCurrentAssetId;
    final entries = [...?timeline?.schedules]
      ..sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
    return [
      const SizedBox(height: 16),
      Text(
        own ? 'Your received timeline' : 'Partner’s received timeline',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (timeline == null) const Text('Timeline not loaded.'),
      if (timeline != null) ...[
        Text('Recipient: ${timeline.recipientId}'),
        Text('Current photo: ${current ?? 'None'}'),
        Text('Fallback: ${timeline.fallbackAssetId ?? 'None'}'),
        Text(
          'Next photo transition (UTC): ${(own ? c.ownResolution : c.partnerResolution)?.nextTransition?.toIso8601String() ?? 'None'}',
        ),
        if (entries.isEmpty) const Text('No scheduled windows.'),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Photo ${entry.assetId}'),
            subtitle: Text(
              '${entry.activeFrom.toUtc().toIso8601String()} → '
              '${entry.activeUntil.toUtc().toIso8601String()}\n'
              'Local: ${entry.activeFrom.toLocal()} → ${entry.activeUntil.toLocal()}',
            ),
            trailing: c.canCancel(entry)
                ? IconButton(
                    key: Key('cancel-schedule-${entry.scheduleId}'),
                    tooltip: 'Cancel schedule',
                    onPressed: c.busy ? null : () => c.cancelSchedule(entry),
                    icon: const Icon(Icons.cancel_outlined),
                  )
                : null,
          ),
      ],
    ];
  }
}
