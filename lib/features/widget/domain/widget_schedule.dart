import 'package:meta/meta.dart';

/// A scheduled window during which a specific photo (`assetId`) should be
/// shown on the partner's home-screen widget.
///
/// Times are absolute instants; comparisons are done in UTC. A window is
/// active for an instant `t` when `activeFrom <= t < activeUntil` (start
/// inclusive, end exclusive). `createdAt` breaks ties when windows overlap:
/// the most recently created window wins, so a last-minute surprise overrides
/// an earlier plan.
@immutable
class WidgetSchedule {
  WidgetSchedule({
    required this.id,
    required this.assetId,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required DateTime createdAt,
  })  : activeFrom = activeFrom.toUtc(),
        activeUntil = activeUntil.toUtc(),
        createdAt = createdAt.toUtc();

  final String id;
  final String assetId;
  final DateTime activeFrom;
  final DateTime activeUntil;
  final DateTime createdAt;

  /// A window is well-formed only if it covers a positive span of time.
  bool get isValid => activeUntil.isAfter(activeFrom);

  /// Whether this window covers the instant [t].
  bool isActiveAt(DateTime t) {
    final u = t.toUtc();
    return !u.isBefore(activeFrom) && u.isBefore(activeUntil);
  }

  /// Whether the window has fully elapsed by [t].
  bool isExpiredAt(DateTime t) => !t.toUtc().isBefore(activeUntil);

  WidgetSchedule copyWith({
    String? id,
    String? assetId,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? createdAt,
  }) {
    return WidgetSchedule(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      activeFrom: activeFrom ?? this.activeFrom,
      activeUntil: activeUntil ?? this.activeUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory WidgetSchedule.fromJson(Map<String, dynamic> json) {
    return WidgetSchedule(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      activeFrom: DateTime.parse(json['active_from'] as String),
      activeUntil: DateTime.parse(json['active_until'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'asset_id': assetId,
      'active_from': activeFrom.toIso8601String(),
      'active_until': activeUntil.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetSchedule &&
      other.id == id &&
      other.assetId == assetId &&
      other.activeFrom == activeFrom &&
      other.activeUntil == activeUntil &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, assetId, activeFrom, activeUntil, createdAt);

  @override
  String toString() =>
      'WidgetSchedule($id, $assetId, $activeFrom→$activeUntil)';
}
