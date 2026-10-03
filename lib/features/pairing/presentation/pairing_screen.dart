import 'package:flutter/material.dart';

import '../../couple/data/couple_repository.dart';
import 'pairing_controller.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.controller});
  final PairingController controller;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final couple = c.couple;
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('Live Serverpod pairing'),
            const SizedBox(height: 12),
            const Text(
              'Development guest account — device-only access. '
              'Signing out, deleting the app, or losing this device can '
              'permanently lose access. No account recovery or linking yet.',
            ),
            const SizedBox(height: 16),
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage(c.error!), key: const Key('pairing-error')),
              TextButton(
                onPressed: c.busy ? null : c.retry,
                child: const Text('Retry'),
              ),
            ],
            if (!c.initialized && !c.busy && c.error == null)
              FilledButton(
                onPressed: c.initialize,
                child: const Text('Connect to server'),
              ),
            if (c.initialized && c.userId == null)
              FilledButton(
                onPressed: c.busy ? null : c.signIn,
                child: const Text('Continue as development guest'),
              ),
            if (c.initialized && c.userId != null) ...[
              SelectableText('Signed in: ${c.userId}'),
              const SizedBox(height: 16),
              Text(
                !c.hasLoadedPairing
                    ? 'Pairing state unavailable — retry or refresh.'
                    : couple == null
                    ? 'Not paired yet'
                    : couple.isComplete
                    ? 'Paired with your partner'
                    : 'Waiting for your partner',
              ),
              if (couple != null) ...[
                SelectableText('Couple: ${couple.id}'),
                Text('Members: ${couple.memberIds.length}/2'),
                Text('Nickname: ${couple.partnerNickname ?? 'Not set'}'),
                Text(
                  'Anniversary: ${couple.anniversary?.toIso8601String() ?? 'Not set'}',
                ),
                Text('Theme: ${couple.themeKey}'),
              ],
              if (c.inviteCode != null) ...[
                const SizedBox(height: 12),
                const Text('Share this invite code privately:'),
                SelectableText(c.inviteCode!, key: const Key('invite-code')),
              ],
              if (c.hasLoadedPairing && couple == null)
                FilledButton(
                  onPressed: c.busy ? null : c.createInvite,
                  child: const Text('Create invite'),
                ),
              if (c.hasLoadedPairing && couple?.isComplete != true) ...[
                TextField(
                  controller: _code,
                  enabled: !c.busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Partner invite code',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: c.busy ? null : () => c.join(_code.text),
                  child: const Text('Join by code'),
                ),
              ],
              OutlinedButton(
                onPressed: c.busy ? null : c.refresh,
                child: const Text('Refresh pairing'),
              ),
              TextButton(
                onPressed: c.busy ? null : () => _confirmSignOut(context),
                child: const Text('Sign out of this device'),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lose guest account access?'),
        content: const Text(
          'This device-only guest account cannot be recovered after sign-out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.controller.signOut();
  }

  String _errorMessage(Object error) {
    if (error is PairingException) {
      return switch (error.error) {
        PairingError.invalidCode => 'Enter a valid invite code.',
        PairingError.codeNotFound => 'That invite code was not found.',
        PairingError.alreadyPaired =>
          'You are already paired. Refresh your pairing.',
        PairingError.cannotPairWithSelf => 'You cannot join your own invite.',
      };
    }
    return 'Server request failed: $error';
  }
}
