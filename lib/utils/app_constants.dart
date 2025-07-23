import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Theme Colors
  static const Color primaryPink = Color(0xFFF48FB1);
  static const Color secondaryPink = Color(0xFFFCE4EC);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color softCream = Color(0xFFFFF8E1);
  static const Color lightPeach = Color(0xFFFFE0B2);

  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);

  static const Color accentBlue = Color(0xFF64B5F6);
  static const Color accentGreen = Color(0xFF81C784);
  static const Color accentYellow = Color(0xFFFFD54F);
  static const Color accentCoral = Color(0xFFF06292);

  static const Color shadowSoft = Color(0x1A000000);
  static const Color borderLight = Color(0xFFE0E0E0);

  static const Color errorRed = Color(0xFFF44336);
  static const Color successGreen = Color(0xFF4CAF50);

  static const Color googleBlue = Color(0xFF4285F4);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkGrey = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF2C2C2C);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color textLightDark = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF424242);

  // Removed AppColors.primaryPink from this list as per request.
  // Added Hot Pink
  static const List<Color> categoryColors = [
    Color(0xFFFF69B4), // Hot Pink - NEW
    Color(0xFF64B5F6), // Accent Blue
    Color(0xFF81C784), // Accent Green
    Color(0xFFFFD54F), // Accent Yellow
    Color(0xFFF06292), // Accent Coral
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE040FB), // Fuchsia
    Color(0xFFC0CA33), // Lime Green
  ];

  // ignore: prefer_typing_uninitialized_variables
  static var primaryPinkValue;
}

class AppTextStyles {
  // This style is for the AppBar, which has a solid color, so text can be white.
  static final TextStyle appTitle = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // FIXED: Removed hardcoded color. The color will be inherited from the theme.
  static final TextStyle modalTitle = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  // FIXED: Removed hardcoded color.
  static final TextStyle taskTitle = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // This style is meant to be pink, so the explicit color is kept.
  static final TextStyle subtaskHeading = GoogleFonts.quicksand(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryPink
  );

  // FIXED: Removed hardcoded color.
  static final TextStyle taskNotes = GoogleFonts.quicksand(
    fontSize: 14,
  );

  // FIXED: Removed hardcoded color.
  static final TextStyle taskMeta = GoogleFonts.quicksand(
    fontSize: 12,
  );

  // FIXED: Removed hardcoded color.
  static final TextStyle bodyText = GoogleFonts.quicksand(
    fontSize: 16,
  );

  // This style is for chips, color is often handled directly in the widget.
  static final TextStyle chipText = GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // This style is for buttons with a solid background, so text can be white.
  static final TextStyle buttonText = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // This style is for the timer, which is always pink.
  static final TextStyle timerText = GoogleFonts.quicksand(
    fontSize: 48.0,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryPink,
  );

  // FIXED: Removed hardcoded color.
  static final TextStyle timerLabel = GoogleFonts.quicksand(
    fontSize: 18.0,
  );
}

extension MonthName on DateTime {
  String monthName() {
    const monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return monthNames[month - 1];
  }
}

class AppConstants {
  static const List<String> weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const List<String> months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
  ];
}