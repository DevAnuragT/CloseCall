import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'editor/widget_editor_screen.dart';

/// The Widget tab entry point. Opens the photo editor; scheduling + sending
/// are wired in once a photo source and the backend are available.
class WidgetTabScreen extends StatelessWidget {
  const WidgetTabScreen({super.key});

  Future<void> _openEditor(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const WidgetEditorScreen()),
    );
    if (bytes != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo ready — scheduling comes next 💛')),
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
