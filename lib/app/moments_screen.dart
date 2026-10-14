import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/moments/presentation/moments_controller.dart';

/// A private scrapbook. Viewing this feed never sends content to a widget.
class MomentsScreen extends StatefulWidget {
  const MomentsScreen({
    super.key,
    this.liveMode = false,
    this.controller,
    this.onConnectPartner,
  });
  final bool liveMode;
  final MomentsController? controller;
  final VoidCallback? onConnectPartner;

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_changed);
    _syncText();
  }

  @override
  void didUpdateWidget(MomentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
      _syncText();
    }
  }

  void _syncText() {
    final text = widget.controller?.draftText ?? '';
    if (_text.text != text) {
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _changed() {
    if (!mounted) return;
    _syncText();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.controller?.setForeground(state == AppLifecycleState.resumed);

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    _text.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.blush,
        backgroundColor: AppColors.card,
        onRefresh: c == null || !c.canCreate ? () async {} : c.refresh,
        child: ListView(
          key: const Key('moments-feed'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Moments',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Small things worth keeping close.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: c?.canCreate == true ? c!.openComposer : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a moment'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _card(
              color: AppColors.plum,
              children: const [
                Icon(Icons.lock_outline_rounded, color: Colors.white),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Just for you two',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'A little note or a familiar voice. Private moments stay in your shared space.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (c == null || !c.canCreate)
              _card(
                children: [
                  Text(
                    widget.liveMode
                        ? 'Connect with your partner'
                        : 'Moments made for two',
                    style: _title,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.liveMode
                        ? 'Pair with your partner to create and see private text and voice moments.'
                        : 'This is a demo preview. Sign in and pair to keep your own moments.',
                  ),
                  if (widget.liveMode && widget.onConnectPartner != null)
                    TextButton(
                      onPressed: widget.onConnectPartner,
                      child: const Text('Connect partner'),
                    ),
                ],
              )
            else ...[
              if (c.composerOpen) ...[
                _composer(c),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (c.loading && c.entries.isNotEmpty)
                const Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (c.feedError != null) ...[
                _notice(c.feedError!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (c.loaded && c.entries.isEmpty && c.feedError == null)
                _card(
                  children: const [
                    Icon(Icons.auto_awesome_outlined, color: AppColors.clay),
                    SizedBox(height: AppSpacing.sm),
                    Text('Your first moment is waiting', style: _title),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Save a small hello, a thought, or a voice note for your partner.',
                    ),
                  ],
                ),
              for (final entry in c.entries) ...[
                _moment(c, entry),
                const SizedBox(height: AppSpacing.md),
              ],
              if (c.hasMore)
                OutlinedButton(
                  onPressed: c.loading ? null : c.loadMore,
                  child: const Text('Load older moments'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer(MomentsController c) {
    final frozen = c.publishing || c.hasPendingPublish;
    return _card(
      children: [
        const Text('Keep a little moment', style: _title),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('moment-text'),
          controller: _text,
          readOnly: frozen,
          onChanged: c.setText,
          minLines: 3,
          maxLines: 8,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Your note',
            hintText: 'What would you like to keep close?',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (c.recording)
          Semantics(
            liveRegion: true,
            child: Text('Recording ${c.recordingSeconds}s / 30s'),
          )
        else if (c.hasVoice)
          Text('Voice moment · ${_duration(c.voiceDurationMs)}'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (c.recording)
              OutlinedButton.icon(
                onPressed: c.audioBusy ? null : c.stopRecording,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop recording'),
              )
            else
              OutlinedButton.icon(
                onPressed: frozen || c.audioBusy ? null : c.record,
                icon: const Icon(Icons.mic_none_rounded),
                label: Text(c.hasVoice ? 'Record again' : 'Record voice'),
              ),
            if (c.hasVoice)
              OutlinedButton.icon(
                onPressed: c.audioBusy || c.recording ? null : c.preview,
                icon: Icon(
                  c.playingId == 'draft'
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  c.playingId == 'draft' ? 'Stop preview' : 'Preview voice',
                ),
              ),
          ],
        ),
        if (c.audioBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(),
          ),
        if (c.audioError != null) _message(c.audioError!),
        if (c.voiceErrorId == 'draft')
          _message('Couldn’t play this preview. Tap Preview voice to retry.'),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Voice notes: up to 30 seconds. Microphone access is requested only when you tap Record.',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        if (c.composerError != null) _message(c.composerError!),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              onPressed: c.publishing || c.recording || c.audioBusy
                  ? null
                  : () async {
                      final success = c.hasPendingPublish
                          ? await c.retryPublish()
                          : await c.publish();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Moment saved for you two.'),
                          ),
                        );
                      }
                    },
              child: Text(
                c.publishing
                    ? 'Publishing…'
                    : c.hasPendingPublish
                    ? 'Retry publication'
                    : 'Publish moment',
              ),
            ),
            TextButton(
              onPressed: c.publishing ? null : c.cancelDraft,
              child: const Text('Cancel moment'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moment(MomentsController c, api.MomentEntry entry) {
    final playing = c.playingId == entry.momentId;
    final loading = c.loadingVoiceId == entry.momentId;
    return _card(
      key: ValueKey('moment-${entry.momentId}'),
      color: c.highlightedMomentId == entry.momentId
          ? AppColors.cream
          : AppColors.card,
      children: [
        Text(c.authorLabel(entry), style: _title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          relativeMomentTime(entry.createdAt),
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        if (entry.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            entry.text,
            style: const TextStyle(color: AppColors.ink, height: 1.4),
          ),
        ],
        if (entry.kind == 'voice') ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: c.recording || c.audioBusy ? null : () => c.play(entry),
            icon: Icon(
              playing || loading
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              loading
                  ? 'Cancel voice loading'
                  : playing
                  ? 'Stop voice'
                  : 'Play voice · ${_duration(entry.durationMs)}',
            ),
          ),
          if (loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading voice moment',
            ),
          if (c.voiceErrorId == entry.momentId)
            _message(
              'Couldn’t play this voice moment. Tap Play voice to retry.',
            ),
        ],
        if (entry.authorId == c.pairing.userId)
          TextButton.icon(
            onPressed: c.deletingId != null
                ? null
                : () => _confirmDelete(c, entry),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(
              c.deletingId == entry.momentId ? 'Deleting…' : 'Delete moment',
            ),
          ),
        if (c.deleteErrorId == entry.momentId)
          _error(
            'Couldn’t delete this moment.',
            'Retry deletion',
            c.retryDelete,
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    MomentsController c,
    api.MomentEntry entry,
  ) async {
    final scope = c.scopeRevision;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this moment?'),
        content: const Text('It will be removed from your shared moments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep moment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted && scope == c.scopeRevision) {
      await c.delete(entry);
    }
  }

  Widget _error(String text, String action, Future<void> Function() retry) =>
      _card(
        children: [
          _message(text),
          TextButton(onPressed: retry, child: Text(action)),
        ],
      );

  Widget _notice(String text) => _card(children: [_message(text)]);
  Widget _message(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Semantics(
      liveRegion: true,
      child: Text(text, style: const TextStyle(color: AppColors.plum)),
    ),
  );
  Widget _card({
    Key? key,
    Color color = AppColors.card,
    required List<Widget> children,
  }) => Container(
    key: key,
    padding: AppSpacing.card,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
  static const _title = TextStyle(
    color: AppColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );
  String _duration(int? ms) =>
      ms == null ? 'Voice note' : '${((ms + 999) ~/ 1000).clamp(1, 30)}s';
}

String relativeMomentTime(DateTime createdAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(createdAt);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  if (age.inDays == 1) return 'Yesterday';
  if (age.inDays < 7) return '${age.inDays} days ago';
  final date = createdAt.toLocal();
  return '${date.day}/${date.month}/${date.year}';
}
