import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../couple/domain/nickname.dart';
import 'pairing_controller.dart';

/// The two labels are private to the signed-in member. Saving updates only the
/// current member's preference row; it never changes the partner's labels.
class NicknameEditor extends StatefulWidget {
  const NicknameEditor({super.key, required this.controller});

  final PairingController controller;

  @override
  State<NicknameEditor> createState() => _NicknameEditorState();
}

class _NicknameEditorState extends State<NicknameEditor> {
  late final TextEditingController _own;
  late final TextEditingController _partner;
  String? _error;
  bool _saved = false;
  String? _scope;
  bool _dirty = false;
  bool _editing = false;
  int _draft = 0;

  @override
  void initState() {
    super.initState();
    _own = TextEditingController();
    _partner = TextEditingController();
    _scope = _scopeFor(widget.controller);
    _reset();
    widget.controller.addListener(_changed);
  }

  String? _scopeFor(PairingController controller) {
    final couple = controller.couple;
    if (controller.userId == null || couple == null) return null;
    return '${controller.userId}/${controller.authRevision}/${couple.id}';
  }

  void _reset() {
    final current = widget.controller.couple;
    final couple = _scope == null || current?.isComplete != true
        ? null
        : current;
    _own.text = couple?.ownNickname ?? '';
    _partner.text = couple?.partnerNickname ?? '';
    _dirty = false;
    _error = null;
    _saved = false;
    _editing = false;
    _draft++;
  }

  void _changed() {
    final scope = _scopeFor(widget.controller);
    if (scope != _scope) {
      _scope = scope;
      _reset(); // Clear old-account drafts before rendering any new scope.
    } else if (!_dirty &&
        !_saved &&
        !widget.controller.nicknameSaving &&
        (_own.text != (widget.controller.couple?.ownNickname ?? '') ||
            _partner.text !=
                (widget.controller.couple?.partnerNickname ?? ''))) {
      _reset();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NicknameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    widget.controller.addListener(_changed);
    _scope = _scopeFor(widget.controller);
    _reset();
  }

  void _edited(String _) => setState(() {
    _dirty = true;
    _saved = false;
    _error = null;
    _draft++;
  });

  void _cancel() {
    final couple = widget.controller.couple;
    setState(() {
      _own.text = couple?.ownNickname ?? '';
      _partner.text = couple?.partnerNickname ?? '';
      _dirty = false;
      _error = null;
      _saved = false;
      _editing = false;
      _draft++;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _own.dispose();
    _partner.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentScope = _scopeFor(widget.controller);
    if (currentScope == null || currentScope != _scope) {
      setState(() => _error = 'Pairing changed. Reopen Profile and try again.');
      return;
    }
    try {
      final own = normalizeNickname(_own.text);
      final partner = normalizeNickname(_partner.text);
      setState(() {
        _error = null;
        _saved = false;
      });
      final draft = _draft;
      final confirmed = await widget.controller.saveNicknames(
        ownNickname: own ?? '',
        partnerNickname: partner ?? '',
      );
      if (!mounted || currentScope != _scope || draft != _draft) return;
      if (confirmed) {
        setState(() {
          _own.text = widget.controller.couple?.ownNickname ?? '';
          _partner.text = widget.controller.couple?.partnerNickname ?? '';
          _dirty = false;
          _saved = true;
          _editing = false;
        });
      } else if (widget.controller.nicknameError != null) {
        final failure = widget.controller.nicknameError;
        setState(
          () => _error = failure is NicknameValidationException
              ? 'Use up to 40 characters, without control characters.'
              : failure is NicknameScopeException
              ? 'Pairing changed. Open Profile again and try again.'
              : 'Could not save nicknames. Try again.',
        );
      }
    } on NicknameValidationException {
      setState(
        () => _error = 'Use up to 40 characters, without control characters.',
      );
    } on NicknameScopeException {
      setState(() => _error = 'Pairing changed. Reopen Profile and try again.');
    } on UnsupportedError {
      setState(() => _error = 'Nickname editing is not available right now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final paired = widget.controller.couple?.isComplete == true;
        final stale = _scopeFor(widget.controller) != _scope;
        final enabled =
            widget.controller.canSaveNicknames &&
            !stale &&
            !widget.controller.busy &&
            !widget.controller.nicknameSaving;
        final couple = paired && _scope != null && !stale
            ? widget.controller.couple
            : null;
        return Container(
          key: const Key('nickname-editor'),
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.cream),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        'Nicknames',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  if (!_editing) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filledTonal(
                      key: const Key('edit-nicknames'),
                      tooltip: 'Edit nicknames',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: AppColors.cream,
                        foregroundColor: AppColors.plum,
                      ),
                      onPressed: enabled
                          ? () => setState(() {
                              _editing = true;
                              _saved = false;
                            })
                          : null,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'The names that feel like you.',
                style: TextStyle(color: AppColors.plum, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.xl),
              _NicknameIdentity(
                label: 'You',
                name: couple?.ownNickname ?? 'Your name',
                icon: Icons.person_outline_rounded,
                tint: AppColors.cream,
                hasNickname: couple?.ownNickname != null,
                editor: _editing
                    ? _nicknameField(
                        key: const Key('own-nickname'),
                        controller: _own,
                        label: 'Your nickname',
                        enabled: enabled,
                      )
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Divider(height: 1, color: AppColors.cream),
              ),
              _NicknameIdentity(
                label: 'Your partner',
                name: couple?.partnerNickname ?? 'Their name',
                icon: Icons.favorite_border_rounded,
                tint: AppColors.blush.withValues(alpha: 0.16),
                hasNickname: couple?.partnerNickname != null,
                editor: _editing
                    ? _nicknameField(
                        key: const Key('partner-nickname'),
                        controller: _partner,
                        label: 'Partner nickname',
                        enabled: enabled,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AppColors.plum,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Just for you. These nicknames are personal and aren’t visible to your partner.',
                        style: TextStyle(
                          color: AppColors.plum,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!paired) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Pair with your partner to add nicknames.',
                  style: TextStyle(color: AppColors.plum, height: 1.4),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, height: 1.4),
                  ),
                ),
              ],
              if (_saved) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Nicknames saved.',
                    style: TextStyle(color: AppColors.plum, height: 1.4),
                  ),
                ),
              ],
              if (_editing) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save-nicknames'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppColors.plum,
                      foregroundColor: AppColors.card,
                    ),
                    onPressed: enabled ? _save : null,
                    child: Semantics(
                      liveRegion: widget.controller.nicknameSaving,
                      child: Text(
                        widget.controller.nicknameSaving
                            ? 'Saving nicknames…'
                            : _error != null
                            ? 'Try saving again'
                            : 'Save nicknames',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('cancel-nicknames'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.plum,
                    ),
                    // Cancelling only discards the local draft. The draft guard
                    // still ignores a late save response after cancellation.
                    onPressed: !widget.controller.busy ? _cancel : null,
                    child: const Text('Cancel edits'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: AppColors.paper,
    contentPadding: const EdgeInsets.all(AppSpacing.lg),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.cream),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.cream),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: const BorderSide(color: AppColors.plum),
    ),
  );

  Widget _nicknameField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool enabled,
  }) => TextField(
    key: key,
    controller: controller,
    onChanged: _edited,
    enabled: enabled,
    maxLength: 40,
    textCapitalization: TextCapitalization.words,
    textInputAction: label == 'Your nickname'
        ? TextInputAction.next
        : TextInputAction.done,
    decoration: _fieldDecoration(label),
  );
}

class _NicknameIdentity extends StatelessWidget {
  const _NicknameIdentity({
    required this.label,
    required this.name,
    required this.icon,
    required this.tint,
    required this.hasNickname,
    this.editor,
  });

  final String label;
  final String name;
  final IconData icon;
  final Color tint;
  final bool hasNickname;
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    return Semantics(
      label: '$label: $name',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: hasNickname && initials.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.plum,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Icon(icon, color: AppColors.plum, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.plum,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                editor ??
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
