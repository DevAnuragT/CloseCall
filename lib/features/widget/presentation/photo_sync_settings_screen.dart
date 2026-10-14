import 'package:flutter/material.dart';

import '../../../core/permissions/notification_permission_service.dart';
import '../../../core/permissions/background_setup_prompt.dart';
import '../../../core/permissions/widget_readiness_controller.dart';
import 'schedule_controller.dart';

const partnerPhotoSetupExplanation =
    'After you add the CloseCall widget, your partner’s sent photos can appear '
    'there. Automatic photo syncing is on by default. Change it in Profile → Settings.';
const foregroundPhotoLimit =
    'New photos sync while CloseCall is open. Notifications are optional for '
    'foreground syncing. Closed-app photo delivery is not available yet.';

Future<void> openPhotoSyncSettings(
  BuildContext context, {
  required ScheduleController schedules,
  WidgetReadinessController? readiness,
  bool setup = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => PhotoSyncSettingsScreen(
      schedules: schedules,
      readiness: readiness,
      setup: setup,
    ),
  ),
);

/// The route retains its opening identity. A later login can never inherit an
/// old switch callback, and completion never blindly pops an editor above it.
class PhotoSyncSettingsScreen extends StatefulWidget {
  const PhotoSyncSettingsScreen({
    super.key,
    required this.schedules,
    this.readiness,
    this.setup = false,
  });
  final ScheduleController schedules;
  final WidgetReadinessController? readiness;
  final bool setup;

  @override
  State<PhotoSyncSettingsScreen> createState() =>
      _PhotoSyncSettingsScreenState();
}

class _PhotoSyncSettingsScreenState extends State<PhotoSyncSettingsScreen> {
  late final _controller = widget.schedules;
  late final _pairing = _controller.pairing;
  late final _identity = (
    _pairing.userId,
    _pairing.authRevision,
    _pairing.couple?.id,
  );
  bool _setupEnabled = true;
  bool get _current =>
      mounted &&
      identical(_controller, widget.schedules) &&
      _identity ==
          (_pairing.userId, _pairing.authRevision, _pairing.couple?.id) &&
      _controller.canSchedule &&
      _pairing.error == null;

  Future<void> _refresh() async {
    if (!_current) return;
    await Future.wait([
      _controller.refresh(),
      if (!_controller.partnerPhotoConsentRestored)
        _controller.retryPartnerPhotoConsent(),
      if (widget.readiness != null) widget.readiness!.refresh(),
    ]);
  }

  Future<void> _finish() async {
    if (!_current || !_controller.canConfigurePartnerPhotos) return;
    await _controller.setPartnerUpdates(_setupEnabled);
    if (!_current ||
        _controller.partnerUpdatesError != null ||
        !_controller.partnerPhotoSetupComplete) {
      return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (ModalRoute.of(context)?.isCurrent == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _controller,
      _pairing,
      _pairing.session,
      widget.readiness,
    ]),
    builder: (context, _) {
      final c = _controller;
      final current = _current;
      final enabled = current && c.canConfigurePartnerPhotos;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.setup ? 'Set up photo syncing' : 'Settings'),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (!current)
                  const Text(
                    'Your account or pairing changed. Close this screen to continue.',
                  )
                else ...[
                  if (widget.setup) ...[
                    const Text(partnerPhotoSetupExplanation),
                    const SizedBox(height: 16),
                    if (c.ownTimeline?.autoUpdateEnabled == false)
                      const Text(
                        'Continuing with syncing on also enables it for your account.',
                      ),
                  ],
                  SwitchListTile(
                    key: const Key('automatic-photo-sync-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatic photo syncing'),
                    value: widget.setup
                        ? _setupEnabled
                        : c.effectivePartnerUpdatesEnabled,
                    subtitle: Text(
                      widget.setup
                          ? 'Your choice is saved only when you finish setup.'
                          : c.restoringPartnerPhotoConsent ||
                                !c.partnerPhotoConsentRestored
                          ? 'Your saved preference will appear shortly.'
                          : c.effectivePartnerUpdatesEnabled
                          ? 'On for your account and this device.'
                          : 'Off on this device. Your current photo stays.',
                    ),
                    onChanged: enabled
                        ? (value) {
                            if (!_current) return;
                            if (widget.setup) {
                              setState(() => _setupEnabled = value);
                            } else {
                              c.setPartnerUpdates(value);
                            }
                          }
                        : null,
                  ),
                  if (!widget.setup && c.needsPartnerPhotoSetup)
                    FilledButton(
                      onPressed: enabled
                          ? () => openPhotoSyncSettings(
                              context,
                              schedules: c,
                              readiness: widget.readiness,
                              setup: true,
                            )
                          : null,
                      child: const Text('Finish photo sync setup'),
                    ),
                  if (c.restoringPartnerPhotoConsent || c.partnerUpdatesBusy)
                    const LinearProgressIndicator(),
                  if (c.partnerUpdatesError != null) ...[
                    const Text(
                      'Could not confirm your photo syncing preference. '
                      'If you turned it off, this device stays paused. Please retry.',
                    ),
                    if (c.hasExplicitPartnerUpdatesRetry)
                      TextButton(
                        key: const Key('photo-sync-retry'),
                        onPressed:
                            c.restoringPartnerPhotoConsent ||
                                c.partnerUpdatesBusy ||
                                !c.foreground
                            ? null
                            : c.retryPartnerUpdates,
                        child: const Text('Retry'),
                      ),
                  ],
                  const SizedBox(height: 20),
                  const Text(foregroundPhotoLimit),
                  const SizedBox(height: 20),
                  if (widget.readiness != null)
                    PhotoSyncDeviceControls(
                      controller: widget.readiness!,
                      enabled:
                          c.foreground &&
                          !c.partnerUpdatesBusy &&
                          !c.restoringPartnerPhotoConsent,
                      isCurrent: () => _current,
                    )
                  else
                    const Text(
                      'Home-screen widgets are currently supported on Android. '
                      'No additional photo-library permissions are needed: choose photos with the system picker.',
                    ),
                ],
                if (widget.setup) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('photo-sync-finish'),
                    onPressed: enabled ? _finish : null,
                    child: const Text('Finish setup'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PhotoSyncDeviceControls extends StatelessWidget {
  const PhotoSyncDeviceControls({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isCurrent,
  });
  final WidgetReadinessController controller;
  final bool enabled;
  final bool Function() isCurrent;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final active = enabled && c.initialised && !c.busy;
    VoidCallback? action(Future<void> Function() callback) => active
        ? () {
            if (isCurrent()) callback();
          }
        : null;
    final allow = c.canRequestNotifications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (c.notificationAccess) {
          NotificationAccess.granted => 'Notifications: allowed',
          NotificationAccess.denied ||
          NotificationAccess.permanentlyDenied => 'Notifications: off',
          NotificationAccess.unsupported =>
            'Notifications: unavailable on this device',
          NotificationAccess.unknown => 'Notifications: not checked yet',
        }),
        if (c.notificationAccess == NotificationAccess.denied ||
            c.notificationAccess == NotificationAccess.permanentlyDenied)
          OutlinedButton(
            key: const Key('sync-notifications-action'),
            onPressed: action(allow ? c.requestNotifications : c.openSettings),
            child: Text(
              allow ? 'Allow notifications' : 'Open notification settings',
            ),
          ),
        const SizedBox(height: 16),
        Text(
          !c.initialised
              ? 'Home widget: setup available below'
              : c.widgetInstalled
              ? 'Home widget: detected on this device'
              : 'Home widget: not detected yet',
          key: const Key('sync-widget-status'),
        ),
        if (c.initialised && !c.widgetInstalled)
          if (c.pinSupported)
            FilledButton(
              key: const Key('sync-add-widget'),
              onPressed: action(c.addWidget),
              child: const Text('Add to home screen'),
            )
          else
            const SizedBox.shrink(),
        if (c.initialised && !c.widgetInstalled) ...[
          const SizedBox(height: 8),
          const Text(
            'To add it manually: touch and hold an empty spot on your home '
            'screen, choose Widgets, then find CloseCall and drag it onto '
            'the home screen. Saving a photo does not add the widget.',
          ),
        ],
        if (c.backgroundSupported && c.backgroundStatus != null) ...[
          const SizedBox(height: 16),
          const Text('Closed-app delivery'),
          const SizedBox(height: 8),
          BackgroundSetupSteps(controller: c),
        ],
        const SizedBox(height: 8),
        const Text(
          'Choose photos with the system picker. No blanket photo-library access is needed.',
        ),
        if (c.error != null)
          const Text('Could not check device setup. Pull down to try again.'),
        if (c.busy) const LinearProgressIndicator(),
      ],
    );
  }
}

/// Persistent, explicit invitation instead of another dialog: it never steals
/// focus from a nickname/photo editor or overlaps the notification invitation.
class PartnerPhotoSetupCoordinator extends StatelessWidget {
  const PartnerPhotoSetupCoordinator({
    super.key,
    required this.schedules,
    required this.child,
    this.readiness,
  });
  final ScheduleController schedules;
  final WidgetReadinessController? readiness;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([schedules, schedules.pairing]),
    builder: (context, _) => Column(
      children: [
        if (schedules.needsPartnerPhotoSetup)
          SafeArea(
            bottom: false,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Your partner photos, on your home screen.'),
                    ),
                    TextButton(
                      key: const Key('open-photo-sync-setup'),
                      onPressed: () => openPhotoSyncSettings(
                        context,
                        schedules: schedules,
                        readiness: readiness,
                        setup: true,
                      ),
                      child: const Text('Set up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    ),
  );
}
