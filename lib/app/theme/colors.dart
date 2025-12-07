import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============ Light Theme Colors ============

  // Primary palette
  static const Color primary = Color(0xFF5D5348);
  static const Color primaryLight = Color(0xFF7D7368);
  static const Color primaryDark = Color(0xFF3D3328);

  // Accent
  static const Color accent = Color(0xFFC9A962);
  static const Color accentLight = Color(0xFFDBC382);
  static const Color accentDark = Color(0xFFA98F42);

  // Background
  static const Color background = Color(0xFFFAF8F5);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFF9B9389);

  // UI Elements
  static const Color border = Color(0xFFE8E4E0);
  static const Color divider = Color(0xFFEEEAE6);
  static const Color shadow = Color(0x1A5D5348);
  static const Color tagBackground = Color(0xFFF5F2EF);

  // Semantic
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);

  // ============ Dark Theme Colors ============

  // Primary palette (dark)
  static const Color primaryDarkTheme = Color(0xFFB5A99A);
  static const Color primaryLightDarkTheme = Color(0xFFD5C9BA);

  // Accent (dark)
  static const Color accentDarkTheme = Color(0xFFDBC382);
  static const Color accentLightDarkTheme = Color(0xFFEBD3A2);

  // Background (dark)
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF2D2D2D);

  // Text (dark)
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textHintDark = Color(0xFF808080);

  // UI Elements (dark)
  static const Color borderDark = Color(0xFF404040);
  static const Color dividerDark = Color(0xFF353535);
  static const Color tagBackgroundDark = Color(0xFF3D3D3D);

  // Semantic (dark)
  static const Color errorDark = Color(0xFFCF6679);
  static const Color successDark = Color(0xFF81C784);
  static const Color warningDark = Color(0xFFFFB74D);

  // ============ Tag Colors ============
  // Predefined colors for tags
  static const List<Color> tagColors = [
    Color(0xFF5D5348), // Brown
    Color(0xFF7B68EE), // Purple
    Color(0xFF20B2AA), // Teal
    Color(0xFFCD853F), // Peru
    Color(0xFF708090), // Slate
    Color(0xFF9370DB), // Medium Purple
    Color(0xFF3CB371), // Medium Sea Green
    Color(0xFFDB7093), // Pale Violet Red
    Color(0xFF4682B4), // Steel Blue
    Color(0xFFDAA520), // Goldenrod
  ];
}
