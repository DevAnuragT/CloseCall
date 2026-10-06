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
import '../data/schedule_repository.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';
import 'schedule_controller.dart';
import 'photo_sync_settings_screen.dart';
import 'schedule_photo_screen.dart';
import 'default_photo_picker.dart';
import 'hub_photo_picker.dart';
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
  Uint8List? _localPhoto;
  Object? _localPhotoScope;
  final _surfaceChanges = ValueNotifier<int>(0);

  Object get _accountScope {
    final pairing = widget.pairing ?? widget.media?.pairing;
    return (
      pairing,
      pairing?.userId,
      pairing?.authRevision,
      pairing?.couple?.id,
      pairing?.couple?.partnerOf(pairing.userId ?? ''),
    );
  }

  @override
  void didUpdateWidget(WidgetTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _surfaceChanges.value++;
    });
  }

  @override
  void dispose() {
    _surfaceChanges.dispose();
    super.dispose();
  }

  Future<void> _openEditor({
    bool blank = false,
    bool upload = false,
    bool send = false,
    Object? expectedScope,
  }) async {
    if (_editing || (expectedScope != null && expectedScope != _accountScope)) {
      return;
    }
    setState(() {
      _editing = true;
      _error = null;
      _status = null;
    });
    _surfaceChanges.value++;
    final scope = widget.media;
    final pairing = widget.pairing ?? scope?.pairing;
    final navigator = Navigator.of(context);
    final identity = pairing?.userId;
    final authRevision = pairing?.authRevision;
    final coupleId = pairing?.couple?.id;
    final partnerId = pairing?.couple?.partnerOf(identity ?? '');
    bool current() =>
        mounted &&
        (pairing == null ||
            (pairing.error == null && pairing.hasLoadedPairing)) &&
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
                ? 'Send this photo to your partner, or save it privately for later.'
                : upload
                ? 'Save this photo privately without sending it.'
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
          setState(() {
            _localPhoto = prepared;
            _localPhotoScope = (
              pairing,
              identity,
              authRevision,
              coupleId,
              partnerId,
            );
            _status = 'Updated this device only — not uploaded.';
          });
        }
      }
    } catch (failure) {
      if (current()) setState(() => _error = failure);
    } finally {
      if (mounted) {
        setState(() => _editing = false);
        _surfaceChanges.value++;
      }
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
      if (pairing?.couple?.isComplete == true &&
          pairing!.userId != null &&
          pairing.couple!.memberIds.contains(pairing.userId)) {
        return _buildPairedHub(
          context,
          media: media,
          pairing: pairing,
          sharingAllowed: sharingAllowed,
        );
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
            const _DemoModeCard(),
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
          ],
        ),
      );
    },
  );

  Widget _buildPairedHub(
    BuildContext context, {
    required MediaController? media,
    required PairingController pairing,
    required bool sharingAllowed,
  }) {
    final schedules = identical(widget.schedules?.pairing, pairing)
        ? widget.schedules
        : null;
    if (schedules == null) {
      return _buildPairedHubContent(
        context,
        media: media,
        pairing: pairing,
        schedules: null,
        sharingAllowed: sharingAllowed,
      );
    }
    return ListenableBuilder(
      listenable: schedules,
      builder: (context, _) => _buildPairedHubContent(
        context,
        media: media,
        pairing: pairing,
        schedules: schedules,
        sharingAllowed: sharingAllowed,
      ),
    );
  }

  Widget _buildPairedHubContent(
    BuildContext context, {
    required MediaController? media,
    required PairingController pairing,
    required ScheduleController? schedules,
    required bool sharingAllowed,
  }) {
    final busy = _editing || media?.busy == true;
    final pending =
        media?.hasPendingUpload == true || media?.hasPendingSend == true;
    return SafeArea(
      child: ListView(
        key: const Key('paired-widget-hub'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text('Your widget', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          _PairedWidgetPreview(
            schedules: schedules,
            localPhoto:
                _localPhotoScope ==
                    (
                      pairing,
                      pairing.userId,
                      pairing.authRevision,
                      pairing.couple?.id,
                      pairing.couple?.partnerOf(pairing.userId ?? ''),
                    )
                ? _localPhoto
                : null,
          ),
          if (widget.readiness != null) ...[
            const SizedBox(height: AppSpacing.md),
            _WidgetSetupSummary(
              controller: widget.readiness!,
              onOpen: () => _showMyWidgetSheet(context),
            ),
          ],
          ..._hubStatus(
            media: media,
            schedules: schedules,
            busy: busy,
            pending: pending,
          ),
          const SizedBox(height: AppSpacing.md),
          _HubActionCard(
            key: const Key('hub-send-to-partner'),
            label: 'Send a photo',
            subtitle: sharingAllowed
                ? 'Choose a photo, decorate it, and send it privately.'
                : 'Complete pairing before sharing private photos.',
            icon: Icons.favorite_outline_rounded,
            accent: AppColors.plum,
            enabled: !busy && !pending && sharingAllowed,
            onTap: () => _showSendSheet(context, media!, pairing),
          ),
          const SizedBox(height: AppSpacing.sm),
          _HubActionCard(
            key: const Key('hub-my-widget'),
            label: 'My widget',
            subtitle: 'Set a photo for this device only, or check setup.',
            icon: Icons.auto_awesome_rounded,
            accent: AppColors.blush,
            onTap: () => _showMyWidgetSheet(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _HubActionCard(
            key: const Key('hub-partner-updates'),
            label: 'Photos from your partner',
            subtitle: schedules == null
                ? 'Photo updates are unavailable right now.'
                : schedules.needsPartnerPhotoSetup
                ? 'Finish setup in Profile → Settings.'
                : schedules.effectivePartnerUpdatesEnabled
                ? 'On · manage automatic syncing in Profile → Settings.'
                : 'Off · manage automatic syncing in Profile → Settings.',
            icon: Icons.sync_rounded,
            accent: AppColors.plum,
            enabled: schedules != null,
            onTap: schedules == null
                ? null
                : () => openPhotoSyncSettings(
                    context,
                    schedules: schedules,
                    readiness: widget.readiness,
                    setup: schedules.needsPartnerPhotoSetup,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _HubActionCard(
            key: const Key('hub-schedule-photo'),
            label: 'Send later',
            subtitle: schedules == null || media == null
                ? 'Photo schedules are unavailable right now.'
                : 'Choose a photo and when to show it.',
            icon: Icons.schedule_rounded,
            accent: AppColors.clay,
            enabled: schedules != null && media != null && sharingAllowed,
            onTap: schedules == null || media == null || !sharingAllowed
                ? null
                : () => _showScheduleSheet(context, schedules, media),
          ),
        ],
      ),
    );
  }

  List<Widget> _hubStatus({
    required MediaController? media,
    required ScheduleController? schedules,
    required bool busy,
    required bool pending,
  }) {
    final widgets = <Widget>[];
    void add(Widget child) {
      widgets
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(child);
    }

    if (_editing) {
      add(
        const WidgetStatusCard(
          key: Key('hub-action-busy'),
          message: 'Photo action in progress…',
          icon: Icons.hourglass_top_rounded,
        ),
      );
    }
    if (schedules?.downloadingNewPhoto == true) {
      add(
        const LinearProgressIndicator(
          key: Key('hub-new-photo-loading'),
          minHeight: 2,
        ),
      );
    }
    if (schedules?.partnerUpdatesError != null) {
      add(
        const WidgetStatusCard(
          key: Key('hub-partner-updates-error'),
          message:
              'Could not change photo updates. Open Profile → Settings to try again.',
          color: AppColors.error,
        ),
      );
    }
    if (_error != null) {
      add(
        WidgetStatusCard(
          key: const Key('photo-local-error'),
          title: 'Photo action needs attention',
          message: mediaErrorMessage(_error!),
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
        ),
      );
    }
    if (media?.error != null) {
      add(
        WidgetStatusCard(
          key: const Key('media-error'),
          title: 'Private photo action needs attention',
          message: media!.hasPendingSend && !media.hasPendingUpload
              ? 'Could not confirm the send. Retry this same photo operation.'
              : mediaErrorMessage(media.error!),
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          action: Wrap(
            children: [
              TextButton(
                onPressed: busy ? null : media.retry,
                child: const Text('Retry photo operation'),
              ),
              if (pending)
                TextButton(
                  onPressed: media.cancel,
                  child: const Text('Cancel photo operation'),
                ),
            ],
          ),
        ),
      );
    } else if (pending) {
      add(
        WidgetStatusCard(
          key: const Key('hub-media-pending'),
          message: media?.hasPendingSend == true
              ? 'Your photo send is pending. Retry explicitly or cancel.'
              : media?.hasPendingUpload == true
              ? 'A private upload is waiting to be retried.'
              : 'Working on your private photo…',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
          action: media == null
              ? null
              : Wrap(
                  children: [
                    if (pending)
                      TextButton(
                        onPressed: busy ? null : media.retry,
                        child: const Text('Retry photo operation'),
                      ),
                    TextButton(
                      onPressed: media.cancel,
                      child: const Text('Cancel photo operation'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (schedules != null && schedules.pendingCreate != null) {
      add(
        WidgetStatusCard(
          key: const Key('hub-schedule-pending'),
          message: 'A schedule is waiting for an explicit retry or discard.',
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
          action: Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: schedules.busy ? null : schedules.retryCreate,
                child: const Text('Retry schedule'),
              ),
              TextButton(
                onPressed: schedules.discardPendingCreate,
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      );
    } else if (schedules?.error != null) {
      add(
        WidgetStatusCard(
          key: const Key('hub-schedule-error'),
          message: _safeHubScheduleError(schedules!.error!),
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          action: TextButton(
            onPressed: schedules.busy ? null : schedules.retry,
            child: const Text('Retry schedule operation'),
          ),
        ),
      );
    } else if (schedules?.streamError != null || schedules?.syncError != null) {
      add(
        WidgetStatusCard(
          key: const Key('hub-timeline-error'),
          message:
              'Could not check for new photos. Try again when you’re online.',
          icon: Icons.wifi_off_rounded,
          color: AppColors.warning,
          action: TextButton(
            onPressed: schedules!.canSchedule && !schedules.busy
                ? schedules.refresh
                : null,
            child: const Text('Try again'),
          ),
        ),
      );
    }
    return widgets;
  }

  String _safeHubScheduleError(Object error) {
    if (error is ScheduleFailure &&
        const {
          'not_paired',
          'asset_not_found',
          'invalid_window',
          'invalid_request_id',
          'request_conflict',
          'schedule_not_found',
          'quota_exceeded',
        }.contains(error.code)) {
      return scheduleErrorMessage(error);
    }
    return 'Could not confirm the schedule operation. Check your connection and retry.';
  }

  Future<void> _showMyWidgetSheet(BuildContext context) {
    final actionScope = _accountScope;
    final pairing = widget.pairing ?? widget.media?.pairing;
    final media =
        widget.media?.canShare == true &&
            identical(pairing, widget.media?.pairing)
        ? widget.media
        : null;
    final schedules = identical(widget.schedules?.pairing, pairing)
        ? widget.schedules
        : null;
    return _showSheet(
      context,
      'My widget',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PairedWidgetPreview(
            schedules:
                identical(
                  widget.schedules?.pairing,
                  widget.pairing ?? widget.media?.pairing,
                )
                ? widget.schedules
                : null,
            localPhoto:
                _localPhotoScope ==
                    (
                      widget.pairing ?? widget.media?.pairing,
                      (widget.pairing ?? widget.media?.pairing)?.userId,
                      (widget.pairing ?? widget.media?.pairing)?.authRevision,
                      (widget.pairing ?? widget.media?.pairing)?.couple?.id,
                      (widget.pairing ?? widget.media?.pairing)?.couple
                          ?.partnerOf(
                            (widget.pairing ?? widget.media?.pairing)?.userId ??
                                '',
                          ),
                    )
                ? _localPhoto
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.readiness != null) ...[
            _WidgetReadinessCard(controller: widget.readiness!),
            const SizedBox(height: AppSpacing.md),
          ],
          WidgetCard(
            eyebrow: 'This device only',
            title: 'Choose your photo',
            icon: Icons.auto_awesome_rounded,
            accent: AppColors.blush,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only changes your widget. Your partner’s widget stays as it is.',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('hub-local-photo'),
                    onPressed:
                        _editing ||
                            widget.media?.busy == true ||
                            widget.media?.hasPendingSend == true ||
                            widget.media?.hasPendingUpload == true
                        ? null
                        : () => _openEditor(expectedScope: actionScope),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose photo'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('hub-blank-canvas'),
                    onPressed:
                        _editing ||
                            widget.media?.busy == true ||
                            widget.media?.hasPendingSend == true ||
                            widget.media?.hasPendingUpload == true
                        ? null
                        : () => _openEditor(
                            blank: true,
                            expectedScope: actionScope,
                          ),
                    icon: const Icon(Icons.crop_square_rounded),
                    label: const Text('Blank canvas'),
                  ),
                ),
              ],
            ),
          ),
          if (media != null && pairing != null) ...[
            const SizedBox(height: AppSpacing.md),
            HubPhotoPicker(
              media: media,
              assets: media.assets
                  .where(
                    (a) =>
                        a.coupleId == pairing.couple?.id &&
                        pairing.couple!.memberIds.contains(a.uploaderId),
                  )
                  .toList(),
              title: 'Saved and received photos',
              onSelect: (asset) => _showAssetPreview(
                context,
                media,
                pairing,
                asset,
                send: false,
              ),
            ),
          ],
          if (media != null && schedules != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                key: const Key('hub-default-photo-setting'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Default photo'),
                children: [
                  DefaultPhotoPicker(controller: schedules, media: media),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            WidgetStatusCard(
              key: const Key('sheet-local-error'),
              message: mediaErrorMessage(_error!),
              color: AppColors.error,
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: AppSpacing.md),
            WidgetStatusCard(message: _status!, color: AppColors.success),
          ],
        ],
      ),
    );
  }

  Future<void> _showScheduleSheet(
    BuildContext context,
    ScheduleController schedules,
    MediaController media,
  ) {
    if (!mounted ||
        !identical(widget.schedules, schedules) ||
        !identical(widget.media, media) ||
        !media.canShare ||
        !identical(schedules.pairing, media.pairing)) {
      return Future.value();
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SchedulePhotoScreen(controller: schedules, media: media),
      ),
    );
  }

  Future<void> _showSendSheet(
    BuildContext context,
    MediaController media,
    PairingController pairing,
  ) {
    if (!mounted ||
        !media.canShare ||
        !identical(media, widget.media) ||
        !identical(pairing, widget.pairing ?? widget.media?.pairing) ||
        !identical(pairing, media.pairing)) {
      return Future.value();
    }
    final actionScope = _accountScope;
    return _showSheet(
      context,
      'Send a photo',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('hub-send-new-photo'),
            onPressed:
                _editing ||
                    media.busy ||
                    media.hasPendingSend ||
                    media.hasPendingUpload
                ? null
                : () => _openEditor(send: true, expectedScope: actionScope),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('New photo'),
          ),
          const SizedBox(height: AppSpacing.lg),
          HubPhotoPicker(
            media: media,
            assets: media.assets
                .where(
                  (a) =>
                      a.coupleId == pairing.couple?.id &&
                      a.uploaderId == pairing.userId,
                )
                .toList(),
            title: 'Saved photos',
            onSelect: (asset) =>
                _showAssetPreview(context, media, pairing, asset, send: true),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssetPreview(
    BuildContext context,
    MediaController media,
    PairingController pairing,
    MediaAsset asset, {
    required bool send,
  }) {
    final identity = pairing.userId;
    final authRevision = pairing.authRevision;
    final couple = pairing.couple?.id;
    final partner = pairing.couple?.partnerOf(identity ?? '');
    bool current() =>
        mounted &&
        identical(widget.media, media) &&
        identical(widget.pairing ?? widget.media?.pairing, pairing) &&
        pairing.error == null &&
        pairing.hasLoadedPairing &&
        pairing.userId == identity &&
        pairing.authRevision == authRevision &&
        pairing.couple?.id == couple &&
        pairing.couple?.partnerOf(pairing.userId ?? '') == partner &&
        asset.coupleId == couple &&
        (!send || asset.uploaderId == identity);
    return _showSheet(
      context,
      send ? 'Send this photo?' : 'Use this photo?',
      () => HubPhotoPreview(
        media: media,
        asset: asset,
        label: send ? 'Send to partner' : 'Use on my widget',
        onConfirm: () async {
          if (!current() ||
              _editing ||
              media.busy ||
              media.hasPendingSend ||
              media.hasPendingUpload) {
            return;
          }
          if (send) {
            await media.sendUploaded(asset);
          } else {
            await media.download(asset);
            if (!current() ||
                media.error != null ||
                media.selectedAsset?.assetId != asset.assetId ||
                media.downloadedPhoto == null) {
              return;
            }
            final photo = media.downloadedPhoto!;
            await media.applyDownloadedLocally();
            if (current() && media.error == null) {
              setState(() {
                _localPhoto = photo;
                _localPhotoScope = (
                  pairing,
                  identity,
                  authRevision,
                  couple,
                  partner,
                );
              });
            }
          }
        },
      ),
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    String title,
    Widget Function() content,
  ) {
    final pairing = widget.pairing ?? widget.media?.pairing;
    final media = widget.media;
    final schedules = widget.schedules;
    final scope = (
      pairing,
      pairing?.userId,
      pairing?.authRevision,
      pairing?.couple?.id,
      pairing?.couple?.partnerOf(pairing.userId ?? ''),
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([
          _surfaceChanges,
          pairing,
          pairing?.session,
          widget.media,
          widget.schedules,
          widget.readiness,
        ]),
        builder: (context, _) {
          final currentPairing = widget.pairing ?? widget.media?.pairing;
          final current =
              mounted &&
              identical(media, widget.media) &&
              identical(schedules, widget.schedules) &&
              scope ==
                  (
                    currentPairing,
                    currentPairing?.userId,
                    currentPairing?.authRevision,
                    currentPairing?.couple?.id,
                    currentPairing?.couple?.partnerOf(
                      currentPairing.userId ?? '',
                    ),
                  ) &&
              currentPairing?.hasLoadedPairing == true &&
              currentPairing?.error == null &&
              currentPairing?.couple?.isComplete == true &&
              currentPairing!.couple!.memberIds.contains(currentPairing.userId);
          return _WidgetBottomSheet(
            title: title,
            child: current
                ? content()
                : const Text('Pairing changed. Close this sheet to continue.'),
          );
        },
      ),
    );
  }
}

class _PairedWidgetPreview extends StatelessWidget {
  const _PairedWidgetPreview({required this.schedules, this.localPhoto});

  final ScheduleController? schedules;
  final Uint8List? localPhoto;

  @override
  Widget build(BuildContext context) {
    // A manual local choice pauses automatic updates; cached partner bytes may
    // still exist in the controller and must not mask that local preview.
    final photo = schedules?.autoSyncEnabled == true
        ? schedules?.currentPhoto ?? localPhoto
        : localPhoto ?? schedules?.currentPhoto;
    return WidgetCard(
      key: const Key('paired-widget-preview'),
      eyebrow: 'Your home widget',
      title: photo == null ? 'Ready for a little moment' : 'Your photo preview',
      icon: Icons.widgets_outlined,
      accent: AppColors.plum,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Semantics(
            label: photo == null
                ? 'Home widget preview placeholder'
                : 'Current home widget photo preview',
            child: Container(
              width: 104,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: photo == null
                  ? const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.clay,
                      size: 30,
                    )
                  : Image.memory(photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Preview only · choose your next moment below.',
              style: TextStyle(color: AppColors.inkMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetSetupSummary extends StatelessWidget {
  const _WidgetSetupSummary({required this.controller, required this.onOpen});

  final WidgetReadinessController controller;
  final VoidCallback onOpen;

  bool get _ready =>
      controller.initialised &&
      controller.widgetInstalled &&
      controller.notificationAccess == NotificationAccess.granted &&
      controller.error == null;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final status = !c.initialised
        ? 'Checking device setup…'
        : c.widgetInstalled
        ? c.notificationAccess == NotificationAccess.granted
              ? 'Widget and notifications are ready'
              : 'Widget added · notifications are off'
        : 'Widget still needs to be added';
    return Semantics(
      button: true,
      label: 'Widget setup readiness. $status. Open setup actions.',
      child: InkWell(
        key: const Key('widget-setup-summary'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onOpen,
        child: WidgetCard(
          key: _ready ? const Key('widget-hub-ready') : null,
          title: 'Widget setup',
          icon: _ready
              ? Icons.check_circle_outline_rounded
              : Icons.widgets_outlined,
          accent: _ready ? AppColors.success : AppColors.clay,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  key: const Key('widget-install-status'),
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onOpen,
                child: Text(_ready ? 'Review' : 'Set up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubActionCard extends StatelessWidget {
  const _HubActionCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: '$label. $subtitle',
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: active ? 0.14 : 0.07),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: active ? accent : AppColors.inkMuted,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: active ? accent : AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WidgetBottomSheet extends StatelessWidget {
  const _WidgetBottomSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.paper,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close $title',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
