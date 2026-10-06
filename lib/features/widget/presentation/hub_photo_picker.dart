import 'dart:async';

import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../media/presentation/media_controller.dart';

/// Loading a thumbnail is read-only: it never selects, sends or applies a photo.
class HubPhotoPicker extends StatelessWidget {
  const HubPhotoPicker({
    super.key,
    required this.media,
    required this.assets,
    required this.title,
    required this.onSelect,
  });

  final MediaController media;
  final List<MediaAsset> assets;
  final String title;
  final ValueChanged<MediaAsset> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (assets.isEmpty)
        const Text(
          'No photos here yet.',
          style: TextStyle(color: AppColors.inkMuted),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 400 ? 3 : 2;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var index = 0; index < assets.length; index++)
                  SizedBox(
                    width: width,
                    child: _PhotoThumbnail(
                      key: ValueKey(('hub-photo', assets[index].assetId)),
                      media: media,
                      asset: assets[index],
                      label:
                          '${assets[index].uploaderId == media.pairing.userId ? 'Saved' : 'Received'} photo ${index + 1}',
                      onTap: () => onSelect(assets[index]),
                    ),
                  ),
              ],
            );
          },
        ),
    ],
  );
}

class _PhotoThumbnail extends StatefulWidget {
  const _PhotoThumbnail({
    super.key,
    required this.media,
    required this.asset,
    required this.label,
    required this.onTap,
  });
  final MediaController media;
  final MediaAsset asset;
  final String label;
  final VoidCallback onTap;
  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  @override
  void initState() {
    super.initState();
    // Defer notifier writes until this frame has finished building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.media.loadPhoto(widget.asset));
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.media,
    builder: (context, _) {
      final photo = widget.media.photoFor(widget.asset.assetId);
      final failed =
          widget.media.photoLoadErrorFor(widget.asset.assetId) != null;
      return Semantics(
        label: widget.label,
        button: true,
        child: Material(
          color: AppColors.cream,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            onTap: widget.onTap,
            child: AspectRatio(
              aspectRatio: 1,
              child: photo != null
                  ? Image.memory(
                      photo,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      cacheWidth: 512,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.clay,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        failed
                            ? Icons.broken_image_outlined
                            : Icons.photo_outlined,
                        color: AppColors.clay,
                      ),
                    ),
            ),
          ),
        ),
      );
    },
  );
}

/// The explicit button is confirmation. Merely opening this preview is read-only.
class HubPhotoPreview extends StatefulWidget {
  const HubPhotoPreview({
    super.key,
    required this.media,
    required this.asset,
    required this.label,
    required this.onConfirm,
  });
  final MediaController media;
  final MediaAsset asset;
  final String label;
  final Future<void> Function() onConfirm;
  @override
  State<HubPhotoPreview> createState() => _HubPhotoPreviewState();
}

class _HubPhotoPreviewState extends State<HubPhotoPreview> {
  bool _working = false;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.media.loadPhoto(widget.asset));
    });
  }

  Future<void> _confirm() async {
    await _runAction(widget.onConfirm);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      if (mounted &&
          widget.media.error == null &&
          !widget.media.hasPendingSend &&
          !widget.media.hasPendingUpload) {
        setState(() => _finished = true);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.media,
    builder: (context, _) {
      final media = widget.media;
      final photo = media.photoFor(widget.asset.assetId);
      final failed = media.photoLoadErrorFor(widget.asset.assetId) != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: photo == null
                  ? ColoredBox(
                      color: AppColors.cream,
                      child: Center(
                        child: Text(
                          failed
                              ? 'Could not load this photo.'
                              : 'Loading photo…',
                        ),
                      ),
                    )
                  : Image.memory(
                      photo,
                      fit: BoxFit.contain,
                      semanticLabel: 'Large photo preview',
                      cacheWidth: 1024,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Could not display this photo.'),
                      ),
                    ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => media.loadPhoto(widget.asset),
              child: const Text('Try loading again'),
            ),
          const SizedBox(height: AppSpacing.md),
          if (_finished)
            Text(
              widget.label == 'Send to partner'
                  ? 'Sent to your partner.'
                  : 'Updated your widget.',
              key: const Key('hub-photo-complete'),
            )
          else
            FilledButton(
              key: const Key('hub-photo-confirm'),
              onPressed:
                  photo == null ||
                      _working ||
                      media.busy ||
                      media.hasPendingSend ||
                      media.hasPendingUpload
                  ? null
                  : _confirm,
              child: Text(widget.label),
            ),
          if (_working) const LinearProgressIndicator(),
          if (media.error != null) ...[
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Could not finish. You can retry or cancel.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: _working || media.busy
                      ? null
                      : () => _runAction(
                          media.hasPendingSend || media.hasPendingUpload
                              ? media.retry
                              : widget.onConfirm,
                        ),
                  child: const Text('Retry'),
                ),
                if (media.hasPendingSend || media.hasPendingUpload)
                  TextButton(
                    onPressed: _working || media.busy ? null : media.cancel,
                    child: const Text('Cancel send'),
                  ),
              ],
            ),
          ],
          TextButton(
            key: const Key('hub-photo-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_finished ? 'Done' : 'Cancel'),
          ),
        ],
      );
    },
  );
}
