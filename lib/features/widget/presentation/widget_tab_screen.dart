import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/home_widget_service.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';

/// The Widget tab entry point. Opens the photo editor, previews the result
/// across widget shapes, and only pushes to the home screen once confirmed.
class WidgetTabScreen extends StatelessWidget {
  const WidgetTabScreen({super.key});

  Future<void> _openEditor(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final bytes = await navigator.push<Uint8List>(
      MaterialPageRoute(builder: (_) => const WidgetEditorScreen()),
    );
    if (bytes == null) return;

    // Confirm against real widget shapes before replacing the home screen.
    final confirmed = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => WidgetPreviewScreen(photo: bytes)),
    );
    if (confirmed != true) return;

    try {
      await HomeWidgetService.setPhoto(bytes);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sent to your home screen 💛')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update the widget: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                size: 56,
                color: AppColors.blush,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Widget',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Design, schedule, and send the home-screen photo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => _openEditor(context),
                child: const Text('Decorate a photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
