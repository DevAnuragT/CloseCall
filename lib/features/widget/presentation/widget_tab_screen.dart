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
  Uint8List? _localPhoto;
  Object? _localPhotoScope;
  final _surfaceChanges = ValueNotifier<int>(0);

  @override
  void dispose() {
    _surfaceChanges.dispose();
    super.dispose();
  }

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
          setState(() {
            _localPhoto = prepared;
            _localPhotoScope = (pairing, identity, authRevision, coupleId);
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
            label: 'Send to partner',
            subtitle: sharingAllowed
                ? 'Choose a photo, decorate it, and send it privately.'
                : 'Complete pairing before sharing private photos.',
            icon: Icons.favorite_outline_rounded,
            accent: AppColors.plum,
            enabled: !busy && !pending && sharingAllowed,
            onTap: () => _openEditor(send: true),
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
            label: 'Partner updates',
            subtitle: schedules == null
                ? 'Partner updates are unavailable right now.'
                : schedules.partnerUpdatesEnabled
                ? 'On while CloseCall is open. Pause whenever you want.'
                : 'Choose whether partner photos can update this device.',
            icon: Icons.sync_rounded,
            accent: AppColors.plum,
            enabled: schedules != null,
            onTap: schedules == null
                ? null
                : () => _showPartnerUpdatesSheet(context, schedules),
          ),
          const SizedBox(height: AppSpacing.sm),
          _HubActionCard(
            key: const Key('hub-schedule-photo'),
            label: 'Schedule a photo',
            subtitle: schedules == null || media == null
                ? 'Photo schedules are unavailable right now.'
                : 'Choose one of your private photos for a time window.',
            icon: Icons.schedule_rounded,
            accent: AppColors.clay,
            enabled: schedules != null && media != null,
            onTap: schedules == null || media == null
                ? null
                : () => _showScheduleSheet(context, schedules, media),
          ),
          if (media != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _HubActionCard(
              key: const Key('hub-my-photos'),
              label: 'My photos',
              subtitle:
                  'Open your private library to send, download, or apply.',
              icon: Icons.photo_library_outlined,
              accent: AppColors.clay,
              onTap: () => _showLibrarySheet(context, media, pairing),
            ),
          ],
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

    if (_editing ||
        schedules?.busy == true ||
        schedules?.syncing == true ||
        schedules?.partnerUpdatesBusy == true) {
      add(
        const WidgetStatusCard(
          key: Key('hub-action-busy'),
          message: 'Photo action in progress…',
          icon: Icons.hourglass_top_rounded,
        ),
      );
    }
    if (_status != null) {
      add(WidgetStatusCard(message: _status!, color: AppColors.success));
    }
    if (schedules?.partnerUpdatesError != null) {
      add(
        const WidgetStatusCard(
          key: Key('hub-partner-updates-error'),
          message:
              'Partner updates could not be changed. Open Partner updates to try again.',
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
    } else if (pending || media?.busy == true) {
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
    } else if (media?.status != null) {
      add(
        WidgetStatusCard(
          message: media!.status!,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
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
              'Timeline needs attention. Reconnect to check the latest photo.',
          icon: Icons.wifi_off_rounded,
          color: AppColors.warning,
          action: TextButton(
            onPressed: schedules!.canSchedule && !schedules.busy
                ? schedules.refresh
                : null,
            child: const Text('Reconnect timeline'),
          ),
        ),
      );
    } else if (schedules?.status != null) {
      add(
        WidgetStatusCard(
          message: schedules!.status!,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
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
            title: 'Choose your local photo',
            icon: Icons.auto_awesome_rounded,
            accent: AppColors.blush,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local widget choices are not uploaded or sent to your partner.',
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
                        : () => _openEditor(),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose a photo'),
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
                        : () => _openEditor(blank: true),
                    icon: const Icon(Icons.crop_square_rounded),
                    label: const Text('Blank canvas'),
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _showPartnerUpdatesSheet(
    BuildContext context,
    ScheduleController schedules,
  ) {
    return _showSheet(
      context,
      'Partner updates',
      () => _PartnerUpdatesCard(
        key: const Key('partner-updates-sheet-card'),
        controller: schedules,
      ),
    );
  }

  Future<void> _showScheduleSheet(
    BuildContext context,
    ScheduleController schedules,
    MediaController media,
  ) {
    return _showSheet(
      context,
      'Schedule a photo',
      () => SchedulePanel(
        controller: schedules,
        media: media,
        showPartnerUpdatesControl: false,
      ),
    );
  }

  Future<void> _showLibrarySheet(
    BuildContext context,
    MediaController media,
    PairingController pairing,
  ) {
    return _showSheet(
      context,
      'My photos',
      () => _PrivatePhotosContent(
        media: media,
        pairing: pairing,
        busy: _editing || media.busy,
        pending: media.hasPendingUpload || media.hasPendingSend,
        sharingAllowed: media.canShare && identical(pairing, media.pairing),
        onSavePhoto: () => _openEditor(upload: true),
      ),
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    String title,
    Widget Function() content,
  ) {
    final pairing = widget.pairing ?? widget.media?.pairing;
    final scope = (
      pairing,
      pairing?.userId,
      pairing?.authRevision,
      pairing?.couple?.id,
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
          widget.media,
          widget.schedules,
          widget.readiness,
        ]),
        builder: (context, _) {
          final currentPairing = widget.pairing ?? widget.media?.pairing;
          final current =
              mounted &&
              scope ==
                  (
                    currentPairing,
                    currentPairing?.userId,
                    currentPairing?.authRevision,
                    currentPairing?.couple?.id,
                  ) &&
              currentPairing?.hasLoadedPairing == true &&
              currentPairing?.error == null &&
              currentPairing?.couple?.isComplete == true;
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

class _PrivatePhotosContent extends StatelessWidget {
  const _PrivatePhotosContent({
    required this.media,
    required this.pairing,
    required this.busy,
    required this.pending,
    required this.sharingAllowed,
    required this.onSavePhoto,
  });

  final MediaController media;
  final PairingController pairing;
  final bool busy;
  final bool pending;
  final bool sharingAllowed;
  final VoidCallback onSavePhoto;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: media,
    builder: (context, _) {
      final coupleId = pairing.couple?.id;
      final assets = media.assets.where((a) => a.coupleId == coupleId).toList();
      final selected = media.selectedAsset;
      final hasDownloaded =
          media.downloadedPhoto != null && selected?.coupleId == coupleId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WidgetCard(
            eyebrow: 'Private library',
            title: 'Photos from your couple',
            icon: Icons.photo_library_outlined,
            accent: AppColors.clay,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your private photos stay in your couple’s storage until you choose what to do next.',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.35),
                ),
                if (!sharingAllowed) ...[
                  const SizedBox(height: AppSpacing.md),
                  const WidgetStatusCard(
                    message: 'Complete pairing before loading private photos.',
                    icon: Icons.people_outline_rounded,
                    color: AppColors.warning,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: busy || pending || !sharingAllowed
                        ? null
                        : onSavePhoto,
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
                        : media.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh private photos'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (assets.isEmpty)
                  const WidgetEmptyState(
                    title: 'Nothing here yet',
                    message:
                        'Uploaded photos will appear here. Tap one to download it before applying it locally.',
                  )
                else
                  Column(
                    children: [
                      for (final asset in assets)
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
              ],
            ),
          ),
          if (hasDownloaded) ...[
            const SizedBox(height: AppSpacing.md),
            WidgetCard(
              eyebrow: 'Ready on this device',
              title: 'Downloaded private photo',
              icon: Icons.download_done_rounded,
              accent: AppColors.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DownloadedPhoto(photo: media.downloadedPhoto!),
                  const SizedBox(height: AppSpacing.md),
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
          if (media.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: WidgetStatusCard(
                message: mediaErrorMessage(media.error!),
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                action: TextButton(
                  onPressed: busy ? null : media.retry,
                  child: const Text('Retry photo operation'),
                ),
              ),
            ),
          if (media.status != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: WidgetStatusCard(
                message: media.status!,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
        ],
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMine
                              ? 'Your private photo'
                              : 'Partner’s private photo',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          asset.createdAt.toLocal().toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (onSend == null)
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(Icons.download_outlined),
                    ),
                ],
              ),
              if (onSend != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send to partner'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
