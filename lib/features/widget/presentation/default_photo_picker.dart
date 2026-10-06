import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/presentation/media_controller.dart';
import 'schedule_controller.dart';
import 'schedule_panel.dart';
import 'widget_ui_components.dart';

class DefaultPhotoPicker extends StatefulWidget {
  const DefaultPhotoPicker({
    super.key,
    required this.controller,
    required this.media,
  });
  final ScheduleController controller;
  final MediaController media;
  @override
  State<DefaultPhotoPicker> createState() => _DefaultPhotoPickerState();
}

class _DefaultPhotoPickerState extends State<DefaultPhotoPicker> {
  late final _scope = scheduleAccountScope(widget.controller);
  String? _selected;
  String? _message;
  String? _error;
  bool get _current =>
      mounted &&
      widget.controller.canSchedule &&
      _scope == scheduleAccountScope(widget.controller);
  Future<void> _save(String asset) async {
    final c = widget.controller;
    if (!_current || c.busy) return;
    setState(() {
      _message = null;
      _error = null;
    });
    await c.setOwnFallback(asset);
    if (!_current) return;
    setState(() {
      _error = c.error == null ? null : friendlyScheduleError(c.error!);
      if (c.error == null && c.ownTimeline?.fallbackAssetId == asset) {
        _message = 'Default photo saved.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.media,
      widget.controller.pairing,
      widget.controller.pairing.session,
    ]),
    builder: (context, _) {
      final c = widget.controller;
      if (_scope != scheduleAccountScope(c)) {
        return const WidgetStatusCard(
          message: 'Pairing changed. Close this screen and try again.',
        );
      }
      if (!c.canSchedule) {
        return const WidgetStatusCard(
          message: 'Complete pairing before choosing a default photo.',
        );
      }
      final assets = widget.media.assets
          .where((a) => a.coupleId == c.pairing.couple?.id)
          .toList();
      final selectedId = _selected ?? c.ownTimeline?.fallbackAssetId;
      final selected = assets.where((a) => a.assetId == selectedId).firstOrNull;
      return WidgetCard(
        title: 'Default photo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your widget uses this photo when there is no scheduled photo or latest photo received from your partner.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (assets.isEmpty)
              const WidgetEmptyState(
                title: 'No photos yet',
                message: 'Photos shared in your couple will appear here.',
              )
            else
              SchedulePhotoGrid(
                media: widget.media,
                assets: assets,
                selectedId: selectedId,
                onChanged: c.busy
                    ? null
                    : (asset) => setState(() {
                        _selected = asset.assetId;
                        _message = null;
                        _error = null;
                      }),
              ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              WidgetStatusCard(message: _error!, color: AppColors.error),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_message != null) ...[
              WidgetStatusCard(message: _message!, color: AppColors.success),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: c.busy || selected == null
                  ? null
                  : () => _save(selected.assetId),
              child: const Text('Save default photo'),
            ),
          ],
        ),
      );
    },
  );
}
