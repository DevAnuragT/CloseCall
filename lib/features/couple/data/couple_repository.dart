import '../domain/couple.dart';

/// Why a pairing attempt failed, for user-facing messaging.
enum PairingError {
  invalidCode,
  codeNotFound,
  alreadyPaired,
  cannotPairWithSelf,
}

class PairingException implements Exception {
  const PairingException(this.error);
  final PairingError error;

  @override
  String toString() => 'PairingException($error)';
}

/// The outcome of starting a pairing: the (incomplete) couple plus the code to
/// share with the partner.
class PairingResult {
  const PairingResult({required this.couple, required this.code});
  final Couple couple;
  final String code;
}

/// Reads and mutates couple/pairing state. The in-memory implementation backs
/// tests and offline demos; the Serverpod implementation backs live pairing.
abstract interface class CoupleRepository {
  /// Starts a pairing for [userId], returning a fresh invite code. If the user
  /// already has a pending couple, its existing code is returned.
  Future<PairingResult> createCouple(String userId);

  /// Joins [userId] to the pending couple identified by [code]. Throws a
  /// [PairingException] on any invalid state.
  Future<Couple> joinByCode(String userId, String code);

  /// The couple [userId] belongs to, or null if unpaired.
  Future<Couple?> coupleForUser(String userId);
}

/// Invite code returned by the most recent server pairing response.
abstract interface class PairingCodeReader {
  String? get currentInviteCode;
}

/// Optional capability: existing pairing-only repositories remain compatible.
abstract interface class NicknameRepository {
  Future<Couple> saveNicknames(
    String userId,
    String coupleId, {
    String? ownNickname,
    String? partnerNickname,
  });
}
