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
        });
      } else if (widget.controller.nicknameError != null) {
        final failure = widget.controller.nicknameError;
        setState(
          () => _error = failure is NicknameValidationException
              ? 'Use up to 40 characters, without control characters.'
              : failure is NicknameScopeException
              ? 'Pairing changed. Refresh Profile and try again.'
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
        return Container(
          key: const Key('nickname-editor'),
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nicknames',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Choose the names you want to see in your private space.',
                style: TextStyle(color: AppColors.inkMuted, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('own-nickname'),
                controller: _own,
                onChanged: _edited,
                enabled: enabled,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your nickname',
                  hintText: 'Your name in this private space',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('partner-nickname'),
                controller: _partner,
                onChanged: _edited,
                enabled: enabled,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Partner nickname',
                  hintText: 'What do you call your partner?',
                ),
              ),
              if (!paired)
                const Text(
                  'Pair with your partner to add nicknames.',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              if (_saved) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Nicknames saved.',
                  style: TextStyle(color: AppColors.success),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-nicknames'),
                  onPressed: enabled ? _save : null,
                  child: Text(
                    widget.controller.nicknameSaving
                        ? 'Saving nicknames…'
                        : 'Save nicknames',
                  ),
                ),
              ),
              TextButton(
                key: const Key('cancel-nicknames'),
                // Cancelling is local and remains safe even if auth/pairing
                // changed while an edit was open.
                onPressed: _dirty && !widget.controller.busy ? _cancel : null,
                child: const Text('Cancel edits'),
              ),
            ],
          ),
        );
      },
    );
  }
}
