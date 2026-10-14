import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'background_reliability_service.dart';
import 'widget_readiness_controller.dart';

/// One-time invitation to relax vendor background limits. Android offers no
/// way to grant autostart silently, so each step opens the system screen and
/// the user decides. It never appears over another active route.
class BackgroundSetupPrompt extends StatefulWidget {
  const BackgroundSetupPrompt({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final WidgetReadinessController controller;

  @override
  State<BackgroundSetupPrompt> createState() => _BackgroundSetupPromptState();
}

class _BackgroundSetupPromptState extends State<BackgroundSetupPrompt> {
  bool _scheduled = false;
  bool _presented = false;
  DialogRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_consider);
    _consider();
  }

  @override
  void didUpdateWidget(BackgroundSetupPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_consider);
      widget.controller.addListener(_consider);
      _consider();
    }
  }

  void _consider() {
    if (!mounted ||
        _scheduled ||
        _presented ||
        !widget.controller.shouldPromptBackground) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          _presented ||
          !widget.controller.shouldPromptBackground ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _presented = true;
      final controller = widget.controller;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            scrollable: true,
            icon: const Icon(Icons.bolt_rounded, color: AppColors.clay),
            title: const Text('Keep CloseCall working when closed'),
            content: BackgroundSetupSteps(controller: controller),
            actions: [
              FilledButton(
                key: const Key('background-setup-done'),
                onPressed: () {
                  _close();
                  unawaited(controller.deferBackgroundPrompt());
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
      _route = route;
      unawaited(
        Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
          if (identical(_route, route)) _route = null;
        }),
      );
    });
  }

  void _close() {
    final route = _route;
    _route = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_consider);
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shared by the setup dialog and Settings so both explain the same two steps.
class BackgroundSetupSteps extends StatelessWidget {
  const BackgroundSetupSteps({super.key, required this.controller});

  final WidgetReadinessController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = controller.backgroundStatus;
      if (status == null) return const SizedBox.shrink();
      final label = autostartSettingLabel(status.manufacturer);
      final idle = !controller.busy;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Some phones stop apps that are closed. To get your partner’s '
            'photos, moments and reminders on time, allow both:',
          ),
          const SizedBox(height: 12),
          if (status.ignoringBatteryOptimizations)
            const ListTile(
              key: Key('background-battery-done'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: AppColors.plum),
              title: Text('Background activity: allowed'),
            )
          else
            OutlinedButton(
              key: const Key('background-battery-action'),
              onPressed: idle ? controller.requestBackgroundExemption : null,
              child: const Text('1. Allow background activity'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('background-autostart-action'),
            onPressed: idle ? controller.openAutostartSettings : null,
            child: Text(
              status.hasVendorAutostartScreen
                  ? '2. Turn on “$label” for CloseCall'
                  : '2. Open CloseCall’s app settings',
            ),
          ),
          if (!status.hasVendorAutostartScreen) ...[
            const SizedBox(height: 8),
            const Text(
              'In app settings, open Battery and choose “Unrestricted” or '
              '“Don’t optimize”.',
            ),
          ],
        ],
      );
    },
  );
}
