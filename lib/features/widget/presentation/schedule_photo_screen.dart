import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../media/presentation/media_controller.dart';
import 'schedule_controller.dart';
import 'schedule_panel.dart';
import 'widget_ui_components.dart';

class SchedulePhotoScreen extends StatefulWidget {
  const SchedulePhotoScreen({
    super.key,
    required this.controller,
    required this.media,
  });
  final ScheduleController controller;
  final MediaController media;
  @override
  State<SchedulePhotoScreen> createState() => _SchedulePhotoScreenState();
}

class _SchedulePhotoScreenState extends State<SchedulePhotoScreen> {
  late final _scope = scheduleAccountScope(widget.controller);

  Future<void> _refresh() async {
    if (_scope != scheduleAccountScope(widget.controller)) return;
    await Future.wait([
      widget.controller.refresh(),
      if (widget.media.canShare) widget.media.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.media,
      widget.controller.pairing,
      widget.controller.pairing.session,
    ]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Send later')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _scope == scheduleAccountScope(widget.controller)
                  ? SchedulePanel(
                      controller: widget.controller,
                      media: widget.media,
                    )
                  : const WidgetStatusCard(
                      message:
                          'Pairing changed. Close this screen and try again.',
                    ),
            ],
          ),
        ),
      ),
    ),
  );
}
