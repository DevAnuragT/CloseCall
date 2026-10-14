import 'dart:async';

import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';

import 'media_controller.dart';

/// A read-only private picture. Mounting (or becoming visible via TickerMode)
/// requests it once. Cache eviction loads again when the preview becomes
/// visible; ordinary photo reads never require a retry button.
class PrivatePhotoPreview extends StatefulWidget {
  const PrivatePhotoPreview({
    super.key,
    required this.media,
    required this.asset,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.compact = false,
  });

  final MediaController media;
  final MediaAsset asset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool compact;

  @override
  State<PrivatePhotoPreview> createState() => _PrivatePhotoPreviewState();
}

class _PrivatePhotoPreviewState extends State<PrivatePhotoPreview> {
  bool _visible = false;
  bool _scheduled = false;
  String? _loadedScope;

  String get _scope =>
      '${widget.media.pairing.authRevision}/'
      '${widget.media.pairing.userId}/'
      '${widget.media.pairing.couple?.id}/'
      '${widget.media.pairing.couple?.memberIds.join('/')}';

  @override
  void initState() {
    super.initState();
    widget.media.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _scheduleLoad();
    _visible = visible;
  }

  @override
  void didUpdateWidget(PrivatePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media) {
      oldWidget.media.removeListener(_changed);
      widget.media.addListener(_changed);
    }
    if (oldWidget.media != widget.media ||
        oldWidget.asset.assetId != widget.asset.assetId ||
        oldWidget.asset.coupleId != widget.asset.coupleId ||
        oldWidget.asset.uploaderId != widget.asset.uploaderId) {
      _loadedScope = null;
      if (_visible) _scheduleLoad();
    }
  }

  void _changed() {
    if (!mounted) return;
    final assetId = widget.asset.assetId;
    final evicted =
        widget.media.photoFor(assetId) == null &&
        !widget.media.photoLoading(assetId) &&
        widget.media.photoLoadErrorFor(assetId) == null;
    if (_visible && (_loadedScope != _scope || evicted)) _scheduleLoad();
    setState(() {});
  }

  void _scheduleLoad() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_visible) return;
      _loadedScope = _scope;
      unawaited(widget.media.loadPhoto(widget.asset));
    });
  }

  @override
  void dispose() {
    widget.media.removeListener(_changed);
    super.dispose();
  }

  Widget _placeholder({required bool loading, required bool failed}) {
    if (loading) {
      return Center(
        child: Semantics(
          label: 'Loading private photo',
          child: const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: widget.compact
          ? Icon(
              failed ? Icons.broken_image_outlined : Icons.photo_outlined,
              semanticLabel: failed
                  ? 'Private photo unavailable'
                  : 'Private photo',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.broken_image_outlined : Icons.photo_outlined,
                  size: 32,
                ),
                if (failed) const Text('Could not load this private photo.'),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reject stale/foreign metadata even if an ID happens to match a cache key.
    final couple = widget.media.pairing.couple;
    final authorized =
        widget.media.canShare &&
        widget.asset.coupleId == couple?.id &&
        couple!.memberIds.contains(widget.asset.uploaderId);
    final photo = authorized
        ? widget.media.photoFor(widget.asset.assetId)
        : null;
    final loading = widget.media.photoLoading(widget.asset.assetId);
    final failed =
        !authorized ||
        widget.media.photoLoadErrorFor(widget.asset.assetId) != null;
    final label = widget.asset.uploaderId == widget.media.pairing.userId
        ? 'Photo from you'
        : 'Photo from your partner';
    return Semantics(
      label: label,
      image: photo != null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: photo == null
              ? _placeholder(loading: loading, failed: failed)
              : Image.memory(
                  photo,
                  fit: widget.fit,
                  excludeFromSemantics: true,
                  // Bound the decoded thumbnail as well as the encoded LRU.
                  cacheWidth: widget.compact
                      ? ((widget.width ?? 88) *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(1, 2048)
                      : null,
                  errorBuilder: (_, _, _) => Center(
                    child: Semantics(
                      label: 'This private photo cannot be displayed',
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Grid/list thumbnail. No ID, timestamp or unsupported sent-history label.
class PrivatePhotoThumbnail extends StatelessWidget {
  const PrivatePhotoThumbnail({
    super.key,
    required this.media,
    required this.asset,
    this.size = 88,
    this.width,
    this.height,
    this.onTap,
  });

  final MediaController media;
  final MediaAsset asset;
  final double size;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Material(
      child: InkWell(
        onTap: onTap,
        child: PrivatePhotoPreview(
          media: media,
          asset: asset,
          width: width ?? size,
          height: height ?? size,
          fit: BoxFit.cover,
          compact: true,
        ),
      ),
    ),
  );
}

/// Opens a read-only large preview; any explicit actions belong to the caller.
Future<void> showPrivatePhotoPreview(
  BuildContext context, {
  required MediaController media,
  required MediaAsset asset,
  List<Widget> actions = const [],
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(
      asset.uploaderId == media.pairing.userId
          ? 'Photo from you'
          : 'Photo from your partner',
    ),
    content: SizedBox(
      width: 520,
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: PrivatePhotoPreview(media: media, asset: asset),
    ),
    actions: [
      ...actions,
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
