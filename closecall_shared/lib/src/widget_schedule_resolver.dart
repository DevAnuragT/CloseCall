import 'widget_schedule.dart';

/// Where the currently-displayed widget photo comes from.
enum WidgetAssetSource { scheduled, fallback }

/// The outcome of resolving what a couple's widget should show *right now*.
class WidgetResolution {
  const WidgetResolution({
    required this.assetId,
    required this.source,
    required this.activeSchedule,
    required this.nextTransition,
  });

  /// The photo that should be displayed.
  final String assetId;

  /// Whether [assetId] came from a schedule or the fallback.
  final WidgetAssetSource source;

  /// The winning schedule, when [source] is [WidgetAssetSource.scheduled].
  final WidgetSchedule? activeSchedule;

  /// The next instant at which the displayed photo would change, or `null` if
  /// nothing further is scheduled. The scheduler uses this to decide when to
  /// next wake the widget (e.g. schedule an FCM push / revert job).
  final DateTime? nextTransition;

  bool get isFallback => source == WidgetAssetSource.fallback;

  @override
  String toString() =>
      'WidgetResolution($assetId, $source, next=$nextTransition)';
}

/// Pure resolver for the signature widget feature: given the current time, a
/// set of scheduled windows, and a fallback photo, decide which photo the
/// home-screen widget should display and when it should next change.
///
/// This is the demo-critical logic — the "appears, then auto-reverts" behavior
/// lives entirely here so it can be exhaustively unit tested without a device.
abstract final class WidgetScheduleResolver {
  /// Resolves the active asset at [now].
  ///
  /// Rules:
  ///  * A schedule applies when `activeFrom <= now < activeUntil`.
  ///  * Overlapping schedules: the one created most recently wins; ties break
  ///    on `id` for determinism.
  ///  * With no applicable schedule the widget reverts to [fallbackAssetId].
  ///  * Malformed windows (`activeUntil <= activeFrom`) are ignored.
  static WidgetResolution resolve({
    required DateTime now,
    required List<WidgetSchedule> schedules,
    required String fallbackAssetId,
  }) {
    final valid = schedules.where((s) => s.isValid).toList(growable: false);
    final winner = _winnerAt(now, valid);

    final currentAsset = winner?.assetId ?? fallbackAssetId;
    final next = _nextTransitionAfter(
      now: now,
      schedules: valid,
      fallbackAssetId: fallbackAssetId,
      currentAsset: currentAsset,
    );

    return WidgetResolution(
      assetId: currentAsset,
      source: winner == null
          ? WidgetAssetSource.fallback
          : WidgetAssetSource.scheduled,
      activeSchedule: winner,
      nextTransition: next,
    );
  }

  /// The schedule that owns the widget at [now], or `null` for the fallback.
  static WidgetSchedule? _winnerAt(DateTime now, List<WidgetSchedule> valid) {
    WidgetSchedule? winner;
    for (final s in valid) {
      if (!s.isActiveAt(now)) continue;
      if (winner == null || _outranks(s, winner)) {
        winner = s;
      }
    }
    return winner;
  }

  /// `a` outranks `b` when it was created later; ties break on id.
  static bool _outranks(WidgetSchedule a, WidgetSchedule b) {
    if (a.createdAt.isAfter(b.createdAt)) return true;
    if (a.createdAt.isBefore(b.createdAt)) return false;
    return a.id.compareTo(b.id) > 0;
  }

  /// Finds the first boundary strictly after [now] where the resolved asset
  /// differs from [currentAsset]. Boundaries are the window starts/ends.
  static DateTime? _nextTransitionAfter({
    required DateTime now,
    required List<WidgetSchedule> schedules,
    required String fallbackAssetId,
    required String currentAsset,
  }) {
    final nowUtc = now.toUtc();
    final boundaries = <DateTime>{};
    for (final s in schedules) {
      if (s.activeFrom.isAfter(nowUtc)) boundaries.add(s.activeFrom);
      if (s.activeUntil.isAfter(nowUtc)) boundaries.add(s.activeUntil);
    }

    final sorted = boundaries.toList()..sort();
    for (final b in sorted) {
      final assetAtB = _winnerAt(b, schedules)?.assetId ?? fallbackAssetId;
      if (assetAtB != currentAsset) return b;
    }
    return null;
  }
}
