import 'package:flutter/widgets.dart';

/// Spacing scale (4pt base) and the generous corner radii that give CloseCall
/// its soft, rounded, non-boxy feel.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Corner radii — intentionally large.
  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusPill = 999;

  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}
