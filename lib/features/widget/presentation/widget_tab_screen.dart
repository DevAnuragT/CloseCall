import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_preparation.dart';
import '../../media/presentation/media_controller.dart';
import '../data/home_widget_service.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';

/// Private upload and this device's widget update are separate, explicit actions.
class WidgetTabScreen extends StatefulWidget {
  const WidgetTabScreen({
    super.key,
    this.media,
    this.liveMode = false,
    this.pickPhoto,
    this.applyLocalPhoto,
  });
  final MediaController? media;
  final bool liveMode;
  final Future<Uint8List?> Function()? pickPhoto;
  final Future<void> Function(Uint8List)? applyLocalPhoto;
  @override
  State<WidgetTabScreen> createState() => _WidgetTabScreenState();
}

class _WidgetTabScreenState extends State<WidgetTabScreen> {
  bool _editing = false;
  Object? _error;
  String? _status;

  Future<void> _openEditor({bool blank = false, bool upload = false}) async {
    if (_editing) return;
    setState(() {
      _editing = true;
      _error = null;
      _status = null;
    });
    final scope = widget.media;
    final navigator = Navigator.of(context);
    final identity = scope?.pairing.userId;
    final coupleId = scope?.pairing.couple?.id;
    bool current() =>
        mounted &&
        identity == scope?.pairing.userId &&
        coupleId == scope?.pairing.couple?.id;
    try {
      Uint8List? background;
      if (!blank) {
        if (widget.pickPhoto != null) {
          background = await widget.pickPhoto!();
        } else {
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 2048,
            maxHeight: 2048,
            requestFullMetadata: false,
          );
          if (picked != null) {
            if (await picked.length() > 20 * 1024 * 1024) {
              throw const FormatException('Selected photo exceeds 20 MiB.');
            }
            background = await picked.readAsBytes();
          }
        }
        if (background == null || !current()) return;
        background = await preparePhotoPng(background);
      }
      if (!current()) return;
      final bytes = await navigator.push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => WidgetEditorScreen(
            background: background == null
                ? null
                : Image.memory(background, fit: BoxFit.cover),
          ),
        ),
      );
      if (bytes == null || !current()) return;
      final prepared = await preparePhotoPng(bytes);
      if (!current()) return;
      final confirmed = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => WidgetPreviewScreen(
            photo: prepared,
            confirmLabel: upload ? 'Upload private photo' : 'Set widget photo',
            actionDescription: upload
                ? 'Upload to your couple’s private server storage only. '
                      'No automatic home-screen delivery or scheduling.'
                : 'Update this device only. This photo will not be uploaded.',
          ),
        ),
      );
      if (confirmed != true || !current()) return;
      if (upload) {
        await scope!.uploadConfirmed(prepared);
      } else {
        if (widget.applyLocalPhoto != null) {
          await widget.applyLocalPhoto!(prepared);
        } else {
          await HomeWidgetService.setPhoto(prepared);
        }
        if (current()) {
          setState(() => _status = 'Updated this device only — not uploaded.');
        }
      }
    } catch (failure) {
      if (current()) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.media ?? const AlwaysStoppedAnimation(0),
    builder: (context, _) {
      final media = widget.media;
      final busy = _editing || media?.busy == true;
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Widget', style: Theme.of(context).textTheme.headlineMedium),
            const Text(
              'Decorate photos, preview widget shapes, then choose an explicit action. '
              'Background delivery and schedules are not available yet.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : () => _openEditor(),
              child: const Text('Decorate a photo — local widget only'),
            ),
            TextButton(
              onPressed: busy ? null : () => _openEditor(blank: true),
              child: const Text('Blank canvas — local widget only'),
            ),
            if (!widget.liveMode)
              const Text('Demo mode: local-only editing. Nothing is uploaded.'),
            if (widget.liveMode) ...[
              if (media?.canShare != true)
                const Text(
                  'Complete pairing in Profile before uploading private photos.',
                ),
              FilledButton.tonal(
                onPressed:
                    busy ||
                        media?.canShare != true ||
                        media?.hasPendingUpload == true
                    ? null
                    : () => _openEditor(upload: true),
                child: const Text('Decorate and upload private photo'),
              ),
              OutlinedButton(
                onPressed: busy || media?.canShare != true
                    ? null
                    : media!.refresh,
                child: const Text('Refresh private photos'),
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                mediaErrorMessage(_error!),
                key: const Key('photo-local-error'),
              ),
            if (_status != null) Text(_status!),
            if (media?.error != null) ...[
              Text(
                mediaErrorMessage(media!.error!),
                key: const Key('media-error'),
              ),
              TextButton(
                onPressed: busy ? null : media.retry,
                child: const Text('Retry photo operation'),
              ),
            ],
            if (media?.busy == true || media?.hasPendingUpload == true)
              TextButton(
                onPressed: media!.cancel,
                child: const Text('Cancel photo operation'),
              ),
            if (media?.hasPendingUpload == true && media?.error == null)
              TextButton(
                onPressed: busy ? null : media!.retryUpload,
                child: const Text('Retry pending upload'),
              ),
            if (media?.status != null) Text(media!.status!),
            if (media?.downloadedPhoto != null) ...[
              const Text('Downloaded private photo'),
              Image.memory(
                media!.downloadedPhoto!,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, error, _) =>
                    Text('Could not display photo: $error'),
              ),
              FilledButton(
                onPressed: busy ? null : media.applyDownloadedLocally,
                child: const Text('Apply downloaded photo to this device'),
              ),
            ],
            if (media != null)
              for (final asset in media.assets)
                ListTile(
                  title: Text(
                    asset.uploaderId == media.pairing.userId
                        ? 'Your private photo'
                        : 'Partner’s private photo',
                  ),
                  subtitle: Text(asset.createdAt.toLocal().toString()),
                  trailing: const Icon(Icons.download),
                  onTap: busy ? null : () => media.download(asset),
                ),
          ],
        ),
      );
    },
  );
}
