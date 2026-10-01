import 'package:flutter/material.dart';

/// CloseCall palette — warm, intimate, calm. Soft blush/clay tones on a
/// near-white "paper" ground, never the high-saturation look of a social app.
abstract final class AppColors {
  // Brand
  static const Color blush = Color(0xFFE8A0A0); // primary — soft rose
  static const Color clay = Color(0xFFD98C7A); // secondary — warm terracotta
  static const Color plum = Color(0xFF6B5B6E); // accent — muted plum text

  // Surfaces
  static const Color paper = Color(0xFFFBF6F2); // app background (warm off-white)
  static const Color card = Color(0xFFFFFFFF); // raised surfaces
  static const Color cream = Color(0xFFF3E9E2); // subtle fills / chips

  // Text
  static const Color ink = Color(0xFF3B3338); // primary text (soft charcoal)
  static const Color inkMuted = Color(0xFF8A7E82); // secondary text

  // Feedback
  static const Color success = Color(0xFF8FB89A);
  static const Color warning = Color(0xFFE0B472);
  static const Color error = Color(0xFFC97B7B);

  /// Mood accent colors, keyed to [MoodKind] names.
  static const Map<String, Color> mood = {
    'happy': Color(0xFFF2C879),
    'tired': Color(0xFF9FB0C9),
    'busy': Color(0xFFC9A27E),
    'stressed': Color(0xFFCF8E8E),
    'missingYou': Color(0xFFE8A0A0),
    'excited': Color(0xFFE79FBF),
  };
}
