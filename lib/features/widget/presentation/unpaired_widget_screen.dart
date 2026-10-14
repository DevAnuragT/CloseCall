import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../media/data/photo_preparation.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/home_widget_service.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_preview_screen.dart';

/// A local-only experience. No library/controller image is used as a preview.
class UnpairedWidgetScreen extends StatefulWidget {
  const UnpairedWidgetScreen({
    super.key,
    required this.pairing,
    this.pickPhoto,
    this.applyLocalPhoto,
    this.onConnectPartner,
  });

  final PairingController pairing;
  final Future<Uint8List?> Function()? pickPhoto;
  final Future<void> Function(Uint8List)? applyLocalPhoto;
  final VoidCallback? onConnectPartner;

  @override
  State<UnpairedWidgetScreen> createState() => _UnpairedWidgetScreenState();
}

class _UnpairedWidgetScreenState extends State<UnpairedWidgetScreen> {
  Uint8List? _photo;
  Uint8List? _retryPhoto;
  bool _busy = false;
  bool _saveFailed = false;
  bool _saved = false;
  String? _error;

  // Check the controller as well as mounted: a route/picker can return before
  // the frame that disposes this state on an account or couple change.
  late final PairingController _pairing;
  late final String? _identity;
  late final int _revision;
  late final String? _coupleId;

  @override
  void initState() {
    super.initState();
    _pairing = widget.pairing;
    _identity = _pairing.userId;
    _revision = _pairing.authRevision;
    _coupleId = _pairing.couple?.id;
  }

  bool get _current =>
      mounted &&
      identical(_pairing, widget.pairing) &&
      _identity == _pairing.userId &&
      _revision == _pairing.authRevision &&
      _coupleId == _pairing.couple?.id &&
      _pairing.hasLoadedPairing &&
      _pairing.error == null &&
      _pairing.couple?.isComplete != true;

  Future<void> _save(Uint8List photo) async {
    if (!_current) return;
    _retryPhoto = photo;
    try {
      await (widget.applyLocalPhoto ?? HomeWidgetService.setPhoto)(photo);
      if (!_current) return;
      setState(() {
        _photo = photo;
        _retryPhoto = null;
        _saveFailed = false;
        _saved = true;
        _error = null;
      });
    } catch (_) {
      if (_current) {
        setState(() {
          _saveFailed = true;
          _error = 'Your photo could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _edit({bool blank = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
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
              throw const FormatException('Photo is too large.');
            }
            background = await picked.readAsBytes();
          }
        }
        if (background == null || !_current) return;
        background = await preparePhotoPng(background);
      }
      if (!_current) return;
      final edited = await navigator.push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => WidgetEditorScreen(
            background: background == null
                ? null
                : Image.memory(background, fit: BoxFit.cover),
          ),
        ),
      );
      if (edited == null || !_current) return;
      final photo = await preparePhotoPng(edited);
      if (!_current) return;
      final confirmed = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => WidgetPreviewScreen(
            photo: photo,
            confirmLabel: 'Set on my widget',
            actionDescription: 'Only on this device. Nothing is shared.',
          ),
        ),
      );
      if (confirmed == true && _current) await _save(photo);
    } catch (_) {
      if (_current) {
        setState(() => _error = 'This photo could not be opened. Try another.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retrySave() async {
    final photo = _retryPhoto;
    if (_busy || photo == null) return;
    setState(() => _busy = true);
    try {
      await _save(photo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        widget.pairing.couple != null || widget.pairing.inviteCode != null;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Material(
      color: AppColors.paper,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.pairing.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const Key('unpaired-widget-list'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(
                'Your widget',
                style: TextStyle(
                  fontSize: largeText ? 24 : 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
              if (!largeText) ...[
                const SizedBox(height: 4),
                const Text(
                  'A little moment, just for you.',
                  style: TextStyle(color: AppColors.plum, fontSize: 15),
                ),
              ],
              const SizedBox(height: 20),
              Semantics(
                label: _photo == null
                    ? 'Illustration of a widget preview. Not an installed widget.'
                    : 'Preview of your local photo. Not an installation check.',
                child: Container(
                  key: const Key('local-widget-preview'),
                  height: 166,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: AppColors.cream,
                  ),
                  child: _photo == null
                      ? const _PreviewIllustration()
                      : Image.memory(_photo!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _photo == null
                    ? 'Preview · illustration'
                    : 'Preview · your photo',
                style: const TextStyle(fontSize: 12, color: AppColors.plum),
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('choose-local-photo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: _busy ? null : () => _edit(),
                child: const Text(
                  'Choose a photo',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only on this device. Nothing is shared.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.plum),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('blank-local-canvas'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.plum,
                ),
                onPressed: _busy ? null : () => _edit(blank: true),
                child: const Text(
                  'Start with a blank canvas',
                  textAlign: TextAlign.center,
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: const Text('Working on your photo…'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const Key('local-photo-error')),
                if (_saveFailed && _retryPhoto != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy ? null : _retrySave,
                    child: const Text('Retry save'),
                  ),
              ],
              if (_saved) ...[
                const SizedBox(height: 12),
                const Text(
                  'Photo saved on this device. Add CloseCall manually to your '
                  'home screen to see it.',
                  key: Key('local-photo-saved'),
                  style: TextStyle(color: AppColors.plum),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.blush.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending ? 'Waiting for your partner' : 'Better together',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pending
                          ? 'Your invitation is ready when they are.'
                          : 'Share little moments with your favorite person.',
                      style: const TextStyle(
                        color: AppColors.plum,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      key: const Key('widget-connect-partner'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.plum,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                      ),
                      onPressed: widget.onConnectPartner,
                      child: Text(pending ? 'View invite' : 'Connect partner'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _WidgetHelp(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetHelp extends StatelessWidget {
  const _WidgetHelp();

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: const Text('How to add the widget', style: TextStyle(fontSize: 14)),
    children: const [
      Text(
        'On Android:\n'
        '1. Touch and hold an empty space on your home screen.\n'
        '2. Tap Widgets and find CloseCall.\n'
        '3. Touch and hold the CloseCall widget, then drag it onto your home screen.\n'
        '4. Resize it if your launcher allows.\n\n'
        'The exact steps can vary by launcher. Saving a photo does not add the widget automatically.',
        style: TextStyle(color: AppColors.plum, height: 1.5),
      ),
    ],
  );
}

class _PreviewIllustration extends StatelessWidget {
  const _PreviewIllustration();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _LandscapePainter()),
        const Center(
          child: Icon(Icons.favorite_rounded, color: Colors.white, size: 42),
        ),
      ],
    ),
  );
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF6DFD8), Color(0xFFE8B5BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .76, size.height * .27),
      24,
      Paint()..color = const Color(0xFFFFF2DD),
    );
    final hill = Path()
      ..moveTo(0, size.height * .78)
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .3,
        size.width * .58,
        size.height * .85,
      )
      ..quadraticBezierTo(
        size.width * .8,
        size.height * .5,
        size.width,
        size.height * .66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()..color = AppColors.plum.withValues(alpha: .20),
    );
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) => false;
}

/// Unknown/error never fall through to either onboarding or private controls.
class WidgetPairingStatus extends StatelessWidget {
  const WidgetPairingStatus({super.key, this.pairing});
  final PairingController? pairing;

  @override
  Widget build(BuildContext context) {
    final failed = pairing?.error != null;
    final signedOut = pairing != null && pairing!.userId == null;
    Future<void> refresh() => pairing == null
        ? Future<void>.value()
        : pairing!.initialized
        ? pairing!.refresh()
        : pairing!.initialize();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Your widget',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            Text(
              failed
                  ? 'We couldn’t check your partner connection.'
                  : signedOut
                  ? 'Sign in to personalize your widget.'
                  : 'Your partner space will appear here when it is ready.',
            ),
          ],
        ),
      ),
    );
  }
}
