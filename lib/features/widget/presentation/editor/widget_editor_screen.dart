import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'editor_painter.dart';
import 'widget_editor_controller.dart';

/// The signature widget-photo editor: draw, add handwritten text and emoji
/// stickers over a photo, then export a flat PNG to send/schedule.
///
/// [background] is the photo being decorated (a plain surface in tests/when no
/// photo is picked yet). [onExport] receives the composited PNG bytes.
class WidgetEditorScreen extends StatefulWidget {
  const WidgetEditorScreen({
    super.key,
    this.background,
    this.onExport,
    this.controller,
  });

  final Widget? background;
  final ValueChanged<Uint8List>? onExport;
  final WidgetEditorController? controller;

  @override
  State<WidgetEditorScreen> createState() => _WidgetEditorScreenState();
}

class _WidgetEditorScreenState extends State<WidgetEditorScreen> {
  final _boundaryKey = GlobalKey();
  late final WidgetEditorController _c =
      widget.controller ?? WidgetEditorController();

  static const _palette = [
    AppColors.blush,
    AppColors.clay,
    AppColors.plum,
    Colors.white,
    Colors.black,
  ];
  static const _emojis = ['❤️', '😘', '✨', '🥺', '😊', '🌙', '💛', '🔥'];
  String _sticker = '❤️';

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails d) {
    switch (_c.tool) {
      case EditorTool.draw:
        break;
      case EditorTool.text:
        _promptForText(d.localPosition);
      case EditorTool.sticker:
        _c.addSticker(_sticker, d.localPosition);
    }
  }

  Future<void> _promptForText(Offset at) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TextInputDialog(),
    );
    if (text != null) _c.addText(text, at);
  }

  /// Flattens the editor surface to PNG bytes.
  Future<Uint8List?> export({double pixelRatio = 3}) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _handleDone() async {
    final bytes = await export();
    if (bytes != null) widget.onExport?.call(bytes);
    if (mounted) Navigator.of(context).maybePop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decorate'),
        actions: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => IconButton(
              key: const Key('editor-undo'),
              icon: const Icon(Icons.undo_rounded),
              onPressed: _c.canUndo ? _c.undo : null,
            ),
          ),
          IconButton(
            key: const Key('editor-clear'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _c.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: AppSpacing.screen,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.background ??
                              Container(color: AppColors.cream),
                          AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) => CustomPaint(
                              painter: EditorPainter(
                                elements: _c.elements,
                                activeStroke: _c.activeStroke,
                              ),
                            ),
                          ),
                          GestureDetector(
                            key: const Key('editor-canvas'),
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _onTapUp,
                            onPanStart: (d) {
                              if (_c.tool == EditorTool.draw) {
                                _c.startStroke(d.localPosition);
                              }
                            },
                            onPanUpdate: (d) {
                              if (_c.tool == EditorTool.draw) {
                                _c.extendStroke(d.localPosition);
                              }
                            },
                            onPanEnd: (_) {
                              if (_c.tool == EditorTool.draw) _c.endStroke();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Toolbar(
            controller: _c,
            palette: _palette,
            emojis: _emojis,
            selectedEmoji: _sticker,
            onEmoji: (e) => setState(() {
              _sticker = e;
              _c.tool = EditorTool.sticker;
            }),
            onDone: _handleDone,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.palette,
    required this.emojis,
    required this.selectedEmoji,
    required this.onEmoji,
    required this.onDone,
  });

  final WidgetEditorController controller;
  final List<Color> palette;
  final List<String> emojis;
  final String selectedEmoji;
  final ValueChanged<String> onEmoji;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: AppSpacing.card,
          color: AppColors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ToolButton(
                    icon: Icons.brush_rounded,
                    tool: EditorTool.draw,
                    controller: controller,
                  ),
                  _ToolButton(
                    icon: Icons.text_fields_rounded,
                    tool: EditorTool.text,
                    controller: controller,
                  ),
                  _ToolButton(
                    icon: Icons.emoji_emotions_rounded,
                    tool: EditorTool.sticker,
                    controller: controller,
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('editor-done'),
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (controller.tool == EditorTool.sticker)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final e in emojis)
                      GestureDetector(
                        onTap: () => onEmoji(e),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: e == selectedEmoji
                                ? AppColors.cream
                                : null,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    for (final c in palette)
                      GestureDetector(
                        onTap: () => controller.color = c,
                        child: Container(
                          margin: const EdgeInsets.only(right: AppSpacing.sm),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: controller.color == c
                                  ? AppColors.ink
                                  : AppColors.cream,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tool,
    required this.controller,
  });

  final IconData icon;
  final EditorTool tool;
  final WidgetEditorController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.tool == tool;
    return IconButton(
      icon: Icon(icon),
      color: selected ? AppColors.blush : AppColors.inkMuted,
      onPressed: () => controller.tool = tool,
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog();

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a note'),
      content: TextField(
        key: const Key('editor-text-field'),
        controller: _field,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Write something…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('editor-text-add'),
          onPressed: () => Navigator.pop(context, _field.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
