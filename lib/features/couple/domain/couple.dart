import 'package:meta/meta.dart';

/// A paired couple: the two member user ids plus the shared, personalizable
/// bits (nickname for the partner, anniversary, chosen theme).
@immutable
class Couple {
  Couple({
    required this.id,
    required this.memberIds,
    this.partnerNickname,
    DateTime? anniversary,
    this.themeKey = 'blush',
  }) : anniversary = anniversary?.toUtc();

  final String id;

  /// Exactly two member user ids once pairing completes.
  final List<String> memberIds;
  final String? partnerNickname;
  final DateTime? anniversary;
  final String themeKey;

  bool get isComplete => memberIds.length == 2;

  /// The other member's id relative to [userId], or null if not resolvable.
  String? partnerOf(String userId) {
    if (!memberIds.contains(userId)) return null;
    return memberIds.firstWhere((id) => id != userId, orElse: () => '');
  }

  Couple copyWith({
    String? id,
    List<String>? memberIds,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
  }) {
    return Couple(
      id: id ?? this.id,
      memberIds: memberIds ?? this.memberIds,
      partnerNickname: partnerNickname ?? this.partnerNickname,
      anniversary: anniversary ?? this.anniversary,
      themeKey: themeKey ?? this.themeKey,
    );
  }

  factory Couple.fromJson(Map<String, dynamic> json) {
    return Couple(
      id: json['id'] as String,
      memberIds: (json['member_ids'] as List).cast<String>(),
      partnerNickname: json['partner_nickname'] as String?,
      anniversary: json['anniversary'] == null
          ? null
          : DateTime.parse(json['anniversary'] as String),
      themeKey: (json['theme_key'] as String?) ?? 'blush',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_ids': memberIds,
        'partner_nickname': partnerNickname,
        'anniversary': anniversary?.toIso8601String(),
        'theme_key': themeKey,
      };

  @override
  bool operator ==(Object other) =>
      other is Couple &&
      other.id == id &&
      _listEq(other.memberIds, memberIds) &&
      other.partnerNickname == partnerNickname &&
      other.anniversary == anniversary &&
      other.themeKey == themeKey;

  @override
  int get hashCode => Object.hash(
        id,
        Object.hashAll(memberIds),
        partnerNickname,
        anniversary,
        themeKey,
      );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
