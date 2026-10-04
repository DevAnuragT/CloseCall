import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'widget_ui_components.dart';

/// A widget shape to preview the photo in. Mirrors the real home-screen sizes
/// a launcher can present, so there are no surprises after sending.
enum WidgetShape {
  medium('Medium', '4 × 2', 2.0, WidgetShapeClip.rounded),
  small('Small', '2 × 2', 1.0, WidgetShapeClip.rounded),
  large('Large', '4 × 4', 1.0, WidgetShapeClip.rounded),
  circle('Circle', 'Clock-style', 1.0, WidgetShapeClip.circle);

  const WidgetShape(this.label, this.sub, this.aspectRatio, this.clip);
  final String label;
  final String sub;
  final double aspectRatio;
  final WidgetShapeClip clip;
}

enum WidgetShapeClip { rounded, circle }

/// Confirmation screen shown after decorating: previews the photo across widget
/// shapes and asks before the caller's explicit local update or private upload.
/// Pops `true` to confirm, `false`/null to keep editing.
class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({
    super.key,
    required this.photo,
    this.confirmLabel = 'Set widget photo',
    this.actionDescription,
  });

  final Uint8List photo;
  final String confirmLabel;
  final String? actionDescription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close preview',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Widget preview'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: const [
                WidgetPill(
                  label: 'PREVIEW',
                  icon: Icons.visibility_outlined,
                  color: AppColors.plum,
                ),
                Spacer(),
                WidgetPill(
                  label: 'CROPS INCLUDED',
                  icon: Icons.crop_free_rounded,
                  color: AppColors.clay,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'How it will look',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              actionDescription ??
                  'Your photo crops to each home-screen shape. Set it when it feels right.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            WidgetCard(
              eyebrow: 'Most common',
              title: 'A wide little moment',
              icon: Icons.web_asset_rounded,
              accent: AppColors.blush,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _ShapeFrame(
                shape: WidgetShape.medium,
                photo: photo,
                hero: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ShapeFrame(shape: WidgetShape.small, photo: photo),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ShapeFrame(shape: WidgetShape.circle, photo: photo),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _ShapeFrame(shape: WidgetShape.large, photo: photo),
          ],
        ),
      ),
      bottomNavigationBar: _ConfirmBar(
        label: confirmLabel,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}

/// One shape preview: the photo cropped into a shape, with a soft shadow and a
/// label beneath.
class _ShapeFrame extends StatelessWidget {
  const _ShapeFrame({
    required this.shape,
    required this.photo,
    this.hero = false,
  });

  final WidgetShape shape;
  final Uint8List photo;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true);
    final radius = BorderRadius.circular(hero ? 24 : 18);
    final clipped = shape.clip == WidgetShapeClip.circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: radius, child: image);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: shape.clip == WidgetShapeClip.circle ? null : radius,
            shape: shape.clip == WidgetShapeClip.circle
                ? BoxShape.circle
                : BoxShape.rectangle,
            boxShadow: [
              BoxShadow(
                color: AppColors.plum.withValues(alpha: 0.16),
                blurRadius: hero ? 28 : 18,
                offset: Offset(0, hero ? 12 : 7),
              ),
            ],
          ),
          child: AspectRatio(aspectRatio: shape.aspectRatio, child: clipped),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          shape.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        Text(
          shape.sub,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// The persistent confirm/cancel footer.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.onConfirm,
    required this.onCancel,
    required this.label,
  });
  final String label;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.plum.withValues(alpha: 0.10)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('preview-confirm'),
                onPressed: onConfirm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              key: const Key('preview-cancel'),
              onPressed: onCancel,
              child: const Text(
                'Keep editing',
                style: TextStyle(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
