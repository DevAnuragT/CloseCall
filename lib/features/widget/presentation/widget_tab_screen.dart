import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/permissions/notification_permission_service.dart';
import '../../../core/permissions/widget_readiness_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_preparation.dart';
import '../../media/presentation/media_controller.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/home_widget_service.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';
import 'schedule_controller.dart';
import 'schedule_panel.dart';
import 'widget_ui_components.dart';
import 'unpaired_widget_screen.dart';

/// Private upload and this device's widget update are separate, explicit actions.
class WidgetTabScreen extends StatefulWidget {
  const WidgetTabScreen({
    super.key,
    this.media,
    this.liveMode = false,
    this.pickPhoto,
    this.applyLocalPhoto,
    this.schedules,
    this.pairing,
    this.onConnectPartner,
    this.readiness,
  });
  final MediaController? media;
  final bool liveMode;
  final Future<Uint8List?> Function()? pickPhoto;
  final Future<void> Function(Uint8List)? applyLocalPhoto;
  final ScheduleController? schedules;
  final PairingController? pairing;
  final VoidCallback? onConnectPartner;
  final WidgetReadinessController? readiness;
  @override
  State<WidgetTabScreen> createState() => _WidgetTabScreenState();
}

class _WidgetTabScreenState extends State<WidgetTabScreen> {
  bool _editing = false;
  Object? _error;
  String? _status;

  Future<void> _openEditor({
    bool blank = false,
    bool upload = false,
    bool send = false,
  }) async {
    if (_editing) return;
    setState(() {
      _editing = true;
      _error = null;
      _status = null;
    });
    final scope = widget.media;
    final pairing = widget.pairing ?? scope?.pairing;
    final navigator = Navigator.of(context);
    final identity = pairing?.userId;
    final authRevision = pairing?.authRevision;
    final coupleId = pairing?.couple?.id;
    final partnerId = pairing?.couple?.partnerOf(identity ?? '');
    bool current() =>
        mounted &&
        identical(scope, widget.media) &&
        identical(pairing, widget.pairing ?? widget.media?.pairing) &&
        identity == pairing?.userId &&
        authRevision == pairing?.authRevision &&
        coupleId == pairing?.couple?.id &&
        partnerId == pairing?.couple?.partnerOf(pairing.userId ?? '');
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
      final confirmed = await navigator.push<Object>(
        MaterialPageRoute(
          builder: (_) => WidgetPreviewScreen(
            photo: prepared,
            confirmLabel: send
                ? 'Send to partner'
                : upload
                ? 'Save privately'
                : 'Set widget photo',
            allowPrivateSave: send,
            actionDescription: send
                ? 'Send this photo to your partner. They must allow updates and open CloseCall to receive new photos. Active schedules take priority. Save privately instead to keep it in your library without sending.'
                : upload
                ? 'Upload to your couple’s private server storage only. '
                      'Scheduling is a separate action; no background delivery.'
                : 'Update this device only. This photo will not be uploaded.',
          ),
        ),
      );
      if (!current()) return;
      if (confirmed == WidgetPreviewAction.savePrivately) {
        await scope!.uploadConfirmed(prepared);
      } else if (confirmed != true) {
        return;
      } else if (send) {
        await scope!.sendConfirmed(prepared);
      } else if (upload) {
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
    listenable: Listenable.merge([
      widget.media,
      widget.pairing ?? widget.media?.pairing,
      widget.readiness,
    ]),
    builder: (context, _) {
      final media = widget.media;
      final pairing = widget.pairing ?? media?.pairing;
      final sharingAllowed =
          media?.canShare == true && identical(pairing, media?.pairing);
      if (widget.liveMode || pairing != null) {
        if (pairing == null ||
            pairing.error != null ||
            pairing.userId == null ||
            !pairing.hasLoadedPairing) {
          return WidgetPairingStatus(pairing: pairing);
        }
        if (pairing.couple?.isComplete != true ||
            !pairing.couple!.memberIds.contains(pairing.userId)) {
          return UnpairedWidgetScreen(
            key: ValueKey((
              pairing,
              pairing.userId,
              pairing.authRevision,
              pairing.couple?.id,
            )),
            pairing: pairing,
            pickPhoto: widget.pickPhoto,
            applyLocalPhoto:
                widget.applyLocalPhoto ??
                widget.schedules?.applyManualPhoto ??
                media?.applyLocalPhoto,
            onConnectPartner: widget.onConnectPartner,
          );
        }
      }
      final busy = _editing || media?.busy == true;
      final pending =
          media?.hasPendingUpload == true || media?.hasPendingSend == true;
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
            if (widget.readiness != null &&
                pairing?.couple?.isComplete == true) ...[
              _WidgetReadinessCard(controller: widget.readiness!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (widget.liveMode &&
                widget.schedules != null &&
                identical(widget.schedules!.pairing, pairing)) ...[
              _PartnerUpdatesCard(
                key: ValueKey((
                  pairing,
                  pairing?.userId,
                  pairing?.authRevision,
                  pairing?.couple?.id,
                )),
                controller: widget.schedules!,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
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
                    onPressed: busy || !sharingAllowed || pending
                        ? null
                        : () => _openEditor(send: true),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose photo'),
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
                      onPressed: busy || pending ? null : () => _openEditor(),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Decorate a photo — local widget only'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy || pending
                          ? null
                          : () => _openEditor(blank: true),
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
                        onPressed: busy || !sharingAllowed || pending
                            ? null
                            : () => _openEditor(upload: true),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Save privately'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy || pending || !sharingAllowed
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
                  message: media!.hasPendingSend && !media.hasPendingUpload
                      ? 'Could not confirm the send. Retry this same photo operation; no new photo will be uploaded after a confirmed upload.'
                      : mediaErrorMessage(media.error!),
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.error,
                  action: TextButton(
                    onPressed: busy ? null : media.retry,
                    child: const Text('Retry photo operation'),
                  ),
                ),
              ),
            ],
            if (media?.busy == true || pending)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: WidgetStatusCard(
                  message: media!.hasPendingSend
                      ? 'Your photo send is pending. Retry explicitly or cancel; it will not resend automatically.'
                      : media.hasPendingUpload
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
            if (media?.downloadedPhoto != null &&
                media?.selectedAsset?.coupleId == pairing?.couple?.id) ...[
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
                        onPressed: busy || pending
                            ? null
                            : media.applyDownloadedLocally,
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
                          for (final asset in media.assets.where(
                            (asset) => asset.coupleId == pairing?.couple?.id,
                          ))
                            _PrivateAssetTile(
                              asset: asset,
                              currentUserId: media.pairing.userId,
                              enabled: !busy && !pending && sharingAllowed,
                              onTap: () => media.download(asset),
                              onSend: asset.uploaderId == media.pairing.userId
                                  ? () => media.sendUploaded(asset)
                                  : null,
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
                  showPartnerUpdatesControl: false,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// OS readiness is not partner-photo consent. None of these actions writes the
/// user's partner-update preference or gates foreground sharing.
class _WidgetReadinessCard extends StatelessWidget {
  const _WidgetReadinessCard({required this.controller});
  final WidgetReadinessController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final access = c.notificationAccess;
    if (c.initialised &&
        c.widgetInstalled &&
        access == NotificationAccess.granted &&
        c.error == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          key: Key('widget-setup-ready'),
          avatar: Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text('Widget ready'),
          backgroundColor: AppColors.cream,
        ),
      );
    }
    final disabled = c.busy || !c.initialised;
    return WidgetCard(
      key: const Key('widget-setup-card'),
      title: 'Widget setup',
      icon: Icons.widgets_outlined,
      accent: AppColors.clay,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !c.initialised
                ? 'Checking this device…'
                : c.widgetInstalled
                ? 'Home widget: installed'
                : 'Home widget: not added yet',
            key: const Key('widget-install-status'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (access) {
            NotificationAccess.granted => 'Notifications: allowed',
            NotificationAccess.denied => 'Notifications: off',
            NotificationAccess.permanentlyDenied =>
              'Notifications: off — change in Settings',
            NotificationAccess.unsupported =>
              'Notifications: unavailable on this device',
            NotificationAccess.unknown => 'Notifications: not checked yet',
          }, key: const Key('widget-notification-status')),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Notifications aren’t required for live updates while the app is '
            'open. Closed-app photo delivery is not available yet.',
            style: TextStyle(color: AppColors.inkMuted, height: 1.35),
          ),
          if (access == NotificationAccess.denied ||
              access == NotificationAccess.unknown ||
              access == NotificationAccess.permanentlyDenied) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('widget-notifications-action'),
                onPressed: disabled
                    ? null
                    : access == NotificationAccess.permanentlyDenied
                    ? c.openSettings
                    : c.requestNotifications,
                child: Text(
                  access == NotificationAccess.permanentlyDenied
                      ? 'Open notification Settings'
                      : 'Allow notifications',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          if (c.initialised && !c.widgetInstalled) ...[
            const SizedBox(height: AppSpacing.sm),
            if (c.pinSupported) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('widget-add-action'),
                  onPressed: disabled ? null : c.addWidget,
                  child: const Text('Add widget'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Confirm on your home screen, then return here to check.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
            ] else
              const Text(
                'Touch and hold an empty spot on your home screen, choose '
                'Widgets, then add CloseCall.',
                key: Key('widget-manual-instructions'),
                style: TextStyle(color: AppColors.inkMuted, height: 1.35),
              ),
          ],
          if (c.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Could not check or change device setup. Please try again.',
              key: Key('widget-readiness-error'),
              style: TextStyle(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('widget-check-setup'),
            onPressed: disabled ? null : c.refresh,
            child: const Text('Check setup'),
          ),
          if (c.busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _PartnerUpdatesCard extends StatefulWidget {
  const _PartnerUpdatesCard({super.key, required this.controller});
  final ScheduleController controller;

  @override
  State<_PartnerUpdatesCard> createState() => _PartnerUpdatesCardState();
}

class _PartnerUpdatesCardState extends State<_PartnerUpdatesCard> {
  bool _hasAllowed = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      _hasAllowed |= c.partnerUpdatesEnabled;
      final disabled = !c.canSchedule || c.partnerUpdatesBusy;
      return WidgetCard(
        eyebrow: 'Photos from your partner',
        title: 'Let their moments find you',
        icon: Icons.favorite_outline_rounded,
        accent: AppColors.plum,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Updates automatically while CloseCall is open. Cached schedules can run later; receiving new photos with the app closed is not available yet.',
              style: TextStyle(color: AppColors.inkMuted, height: 1.35),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_hasAllowed)
              FilledButton.icon(
                key: const Key('allow-partner-updates'),
                onPressed: disabled ? null : () => c.setPartnerUpdates(true),
                icon: const Icon(Icons.favorite_outline_rounded),
                label: const Text('Allow partner updates'),
              )
            else
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  key: const Key('partner-updates-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow partner updates'),
                  subtitle: Text(
                    c.partnerUpdatesEnabled
                        ? 'On — pause whenever you want. Local-only photo choices pause updates.'
                        : 'Paused — resume when you’re ready.',
                  ),
                  value: c.partnerUpdatesEnabled,
                  onChanged: disabled ? null : c.setPartnerUpdates,
                ),
              ),
            if (c.partnerUpdatesBusy) const LinearProgressIndicator(),
            if (c.partnerUpdatesError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              WidgetStatusCard(
                key: const Key('partner-updates-error'),
                message:
                    'Could not change partner updates. Check your connection and try again.',
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
              ),
            ],
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            const _HeaderPill(
              label: 'HOME WIDGET',
              icon: Icons.widgets_outlined,
              color: AppColors.plum,
            ),
            _HeaderPill(
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
              ? 'Send a photo to your partner, or make something just for this device.'
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

/// Unlike a single-line pill, this can wrap at large accessibility text sizes.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
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
    this.onSend,
  });

  final MediaAsset asset;
  final String? currentUserId;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onSend;

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
        trailing: onSend == null
            ? const Icon(Icons.download_outlined)
            : TextButton.icon(
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send to partner'),
              ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
