import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'widget_readiness_controller.dart';

/// One installation-level invitation, independent of account and pairing routes.
/// The OS request is only made by the explicit Allow button.
class PermissionOnboarding extends StatefulWidget {
  const PermissionOnboarding({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final WidgetReadinessController controller;

  @override
  State<PermissionOnboarding> createState() => _PermissionOnboardingState();
}

class _PermissionOnboardingState extends State<PermissionOnboarding> {
  bool _scheduled = false;
  bool _presented = false;
  bool _interactionStarted = false;
  DialogRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_considerPrompt);
    _considerPrompt();
  }

  @override
  void didUpdateWidget(PermissionOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_considerPrompt);
      widget.controller.addListener(_considerPrompt);
      _removePromptAfterFrame();
      _considerPrompt();
    }
  }

  void _considerPrompt() {
    if (!mounted ||
        _scheduled ||
        _presented ||
        !widget.controller.shouldPrompt) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _presented || !widget.controller.shouldPrompt) return;
      if (_interactionStarted) {
        _presented = true;
        unawaited(widget.controller.deferPrompt());
        return;
      }
      // Never layer this invitation over verification or another active route.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _presented = true;
      final controller = widget.controller;
      final navigator = Navigator.of(context, rootNavigator: true);
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            scrollable: true,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.clay,
            ),
            title: const Text('Allow CloseCall notifications?'),
            content: const Text(
              'Allow notifications for CloseCall updates. You can change this '
              'later in Widget setup.\n\n'
              'Notifications aren’t required for live updates while the app is '
              'open. Closed-app photo delivery is not available yet.',
            ),
            actions: [
              TextButton(
                key: const Key('permission-not-now'),
                onPressed: () {
                  _closePrompt();
                  unawaited(controller.deferPrompt());
                },
                child: const Text('Not now'),
              ),
              FilledButton(
                key: const Key('permission-allow'),
                onPressed: () {
                  // Close our own route before entering OS UI. A returning
                  // request must never pop a new identity's or editor's route.
                  _closePrompt();
                  unawaited(controller.requestNotifications());
                },
                child: const Text('Allow notifications'),
              ),
            ],
          ),
        ),
      );
      _route = route;
      unawaited(
        navigator.push(route).whenComplete(() {
          if (identical(_route, route)) _route = null;
        }),
      );
    });
  }

  void _closePrompt() {
    final route = _route;
    _route = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  void _removePromptAfterFrame() {
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_considerPrompt);
    // Teardown may happen while the navigator is rebuilding. Remove only our
    // route after that frame; never use a generic pop against a new screen.
    _removePromptAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    // A slow device check must not interrupt an email flow already in progress.
    onPointerDown: (_) => _interactionStarted = true,
    child: widget.child,
  );
}
