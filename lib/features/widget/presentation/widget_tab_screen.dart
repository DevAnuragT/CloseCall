import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_preparation.dart';
import '../../media/presentation/media_controller.dart';
import '../data/home_widget_service.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';
import 'schedule_controller.dart';
import 'schedule_panel.dart';
import 'widget_ui_components.dart';

/// Private upload and this device's widget update are separate, explicit actions.
class WidgetTabScreen extends StatefulWidget {
  const WidgetTabScreen({
    super.key,
    this.media,
    this.liveMode = false,
    this.pickPhoto,
    this.applyLocalPhoto,
    this.schedules,
  });
  final MediaController? media;
  final bool liveMode;
  final Future<Uint8List?> Function()? pickPhoto;
  final Future<void> Function(Uint8List)? applyLocalPhoto;
  final ScheduleController? schedules;
  @override
  State<WidgetTabScreen> createState() => _WidgetTabScreenState();
}

class _WidgetTabScreenState extends State<WidgetTabScreen> {
  bool _editing = false;
  Object? _error;
  String? _status;

  Future<void> _openEditor({bool blank = false, bool upload = false}) async {
    if (_editing) return;
    setState(() {
      _editing = true;
      _error = null;
      _status = null;
    });
    final scope = widget.media;
    final navigator = Navigator.of(context);
    final identity = scope?.pairing.userId;
    final coupleId = scope?.pairing.couple?.id;
    bool current() =>
        mounted &&
        identity == scope?.pairing.userId &&
        coupleId == scope?.pairing.couple?.id;
    try {
      Uint8List? background;
      if (!blank) {
        if (widget.pickPhoto != null) {
          background = await widget.pickPhoto!();
        } else {
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 2048,
            maxHeight: 2048,
            requestFullMetadata: false,
          );
          if (picked != null) {
            if (await picked.length() > 20 * 1024 * 1024) {
              throw const FormatException('Selected photo exceeds 20 MiB.');
            }
            background = await picked.readAsBytes();
          }
        }
        if (background == null || !current()) return;
        background = await preparePhotoPng(background);
      }
      if (!current()) return;
      final bytes = await navigator.push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => WidgetEditorScreen(
            background: background == null
                ? null
                : Image.memory(background, fit: BoxFit.cover),
          ),
        ),
      );
      if (bytes == null || !current()) return;
      final prepared = await preparePhotoPng(bytes);
      if (!current()) return;
      final confirmed = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => WidgetPreviewScreen(
            photo: prepared,
            confirmLabel: upload ? 'Upload private photo' : 'Set widget photo',
            actionDescription: upload
                ? 'Upload to your couple’s private server storage only. '
                      'Scheduling is a separate action; no background delivery.'
                : 'Update this device only. This photo will not be uploaded.',
          ),
        ),
      );
      if (confirmed != true || !current()) return;
      if (upload) {
        await scope!.uploadConfirmed(prepared);
      } else {
        if (widget.applyLocalPhoto != null) {
          await widget.applyLocalPhoto!(prepared);
        } else if (widget.schedules != null) {
          await widget.schedules!.applyManualPhoto(prepared);
        } else {
          await HomeWidgetService.setPhoto(prepared);
        }
        if (current()) {
          setState(() => _status = 'Updated this device only — not uploaded.');
        }
      }
    } catch (failure) {
      if (current()) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.media ?? const AlwaysStoppedAnimation(0),
    builder: (context, _) {
      final media = widget.media;
      final busy = _editing || media?.busy == true;
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _WidgetHeader(liveMode: widget.liveMode),
            const SizedBox(height: AppSpacing.md),
            if (widget.liveMode)
              WidgetCard(
                eyebrow: 'Share privately',
                title: 'Send a little something',
                icon: Icons.lock_outline_rounded,
                accent: AppColors.plum,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed:
                        busy ||
                            media?.canShare != true ||
                            media?.hasPendingUpload == true
                        ? null
                        : () => _openEditor(upload: true),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Decorate and upload private photo'),
                  ),
                ),
              ),
            if (widget.liveMode) const SizedBox(height: AppSpacing.md),
            WidgetCard(
              eyebrow: 'On this device',
              title: 'Make the next glance yours',
              icon: Icons.auto_awesome_rounded,
              accent: AppColors.blush,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Decorate a photo for this device. Nothing leaves it.',
                    style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _openEditor(),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Decorate a photo — local widget only'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _openEditor(blank: true),
                      icon: const Icon(Icons.crop_square_rounded),
                      label: const Text('Blank canvas — local widget only'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!widget.liveMode) const _DemoModeCard(),
            if (widget.liveMode) ...[
              WidgetCard(
                eyebrow: 'Private library',
                title: 'Share when you choose',
                icon: Icons.lock_outline_rounded,
                accent: AppColors.plum,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private uploads stay in your couple’s storage until you choose what to do next.',
                      style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                    ),
                    if (media?.canShare != true) ...[
                      const SizedBox(height: AppSpacing.md),
                      const WidgetStatusCard(
                        message:
                            'Complete pairing in Profile before uploading private photos.',
                        icon: Icons.people_outline_rounded,
                        color: AppColors.warning,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed:
                            busy ||
                                media?.canShare != true ||
                                media?.hasPendingUpload == true
                            ? null
                            : () => _openEditor(upload: true),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Upload another private photo'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy || media?.canShare != true
                            ? null
                            : media!.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh private photos'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: const LinearProgressIndicator(minHeight: 5),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  key: const Key('photo-local-error'),
                  title: 'Photo action could not finish',
                  message: mediaErrorMessage(_error!),
                  icon: Icons.error_outline_rounded,
                  color: AppColors.error,
                ),
              ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  message: _status!,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ),
            if (media?.error != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  key: const Key('media-error'),
                  title: 'Private photo action needs attention',
                  message: mediaErrorMessage(media!.error!),
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.error,
                  action: TextButton(
                    onPressed: busy ? null : media.retry,
                    child: const Text('Retry photo operation'),
                  ),
                ),
              ),
            ],
            if (media?.busy == true || media?.hasPendingUpload == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  message: media!.hasPendingUpload
                      ? 'A private upload is waiting to be retried.'
                      : 'Working on your private photo…',
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  action: TextButton(
                    onPressed: media.cancel,
                    child: const Text('Cancel photo operation'),
                  ),
                ),
              ),
            if (media?.hasPendingUpload == true && media?.error == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: busy ? null : media!.retryUpload,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Retry pending upload'),
                  ),
                ),
              ),
            if (media?.status != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  message: media!.status!,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ),
            if (media?.downloadedPhoto != null) ...[
              const SizedBox(height: AppSpacing.xl),
              WidgetCard(
                eyebrow: 'Ready on this device',
                title: 'Downloaded private photo',
                icon: Icons.download_done_rounded,
                accent: AppColors.success,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DownloadedPhoto(photo: media!.downloadedPhoto!),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : media.applyDownloadedLocally,
                        icon: const Icon(Icons.phone_android_rounded),
                        label: const Text(
                          'Apply downloaded photo to this device',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (media != null) ...[
              const SizedBox(height: AppSpacing.xl),
              WidgetCard(
                eyebrow: 'Private library',
                title: 'Photos from your couple',
                icon: Icons.photo_library_outlined,
                accent: AppColors.clay,
                child: media.assets.isEmpty
                    ? const WidgetEmptyState(
                        title: 'Nothing here yet',
                        message:
                            'Uploaded photos will appear here. Tap one to download it before applying it locally.',
                      )
                    : Column(
                        children: [
                          for (final asset in media.assets)
                            _PrivateAssetTile(
                              asset: asset,
                              currentUserId: media.pairing.userId,
                              enabled: !busy,
                              onTap: () => media.download(asset),
                            ),
                        ],
                      ),
              ),
            ],
            if (widget.schedules != null && media != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: SchedulePanel(
                  controller: widget.schedules!,
                  media: media,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _WidgetHeader extends StatelessWidget {
  const _WidgetHeader({required this.liveMode});

  final bool liveMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const WidgetPill(
              label: 'HOME WIDGET',
              icon: Icons.widgets_outlined,
              color: AppColors.plum,
            ),
            const Spacer(),
            WidgetPill(
              label: liveMode ? 'PRIVATE' : 'DEMO',
              icon: liveMode ? Icons.lock_outline : Icons.visibility_outlined,
              color: liveMode ? AppColors.success : AppColors.clay,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'A little closer,\nevery glance.',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          liveMode
              ? 'Choose what this device shows. Sharing and schedules stay explicit.'
              : 'Create a small, personal moment for this device.',
          style: const TextStyle(
            color: AppColors.inkMuted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DemoModeCard extends StatelessWidget {
  const _DemoModeCard();

  @override
  Widget build(BuildContext context) {
    return const WidgetStatusCard(
      message: 'Demo mode: local-only editing. Nothing is uploaded.',
      icon: Icons.visibility_outlined,
      color: AppColors.clay,
    );
  }
}

class _DownloadedPhoto extends StatelessWidget {
  const _DownloadedPhoto({required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Image.memory(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not display photo: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateAssetTile extends StatelessWidget {
  const _PrivateAssetTile({
    required this.asset,
    required this.currentUserId,
    required this.enabled,
    required this.onTap,
  });

  final MediaAsset asset;
  final String? currentUserId;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMine = asset.uploaderId == currentUserId;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: (isMine ? AppColors.blush : AppColors.plum)
              .withValues(alpha: 0.14),
          child: Icon(
            isMine
                ? Icons.person_outline_rounded
                : Icons.favorite_outline_rounded,
            color: isMine ? AppColors.clay : AppColors.plum,
            size: 20,
          ),
        ),
        title: Text(isMine ? 'Your private photo' : 'Partner’s private photo'),
        subtitle: Text(
          asset.createdAt.toLocal().toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.download_outlined),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
