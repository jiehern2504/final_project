import 'package:flutter/material.dart';

/// Shared palette aligned with [HomePage].
abstract final class AppColors {
  static const Color primary = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFFFFB74D);
  static const Color background = Color(0xFFF9FBF9);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF757575);

  /// Muted grey-green used for captions / secondary labels on light cards.
  static const Color muted = Color(0xFF7A8A80);

  /// Hairline border colour for cards and dividers.
  static const Color hairline = Color(0xFFE6EFE8);
}
