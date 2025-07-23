import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum to represent the different theme modes
enum AppThemeMode {
  system,
  light,
  dark,
}

/// A [ChangeNotifier] to manage the application's theme mode.
/// It persists the selected theme mode using [SharedPreferences].
class ThemeModeNotifier extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system; // Default to system theme

  ThemeModeNotifier() {
    _loadThemeModeFromPrefs();
  }

  // Getter to access the current theme mode
  AppThemeMode get themeMode => _themeMode;

  /// Sets the new theme mode and saves it to [SharedPreferences].
  /// Notifies listeners about the change.
  Future<void> setThemeMode(AppThemeMode newThemeMode) async {
    if (_themeMode != newThemeMode) {
      _themeMode = newThemeMode;
      await _saveThemeModeToPrefs(newThemeMode);
      notifyListeners(); // Notify all listening widgets to rebuild
    }
  }

  /// Loads the saved theme mode from [SharedPreferences].
  Future<void> _loadThemeModeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedThemeMode = prefs.getString(_themeModeKey);

    if (savedThemeMode != null) {
      try {
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.toString() == 'AppThemeMode.$savedThemeMode',
          orElse: () => AppThemeMode.system, // Fallback if value is invalid
        );
      } catch (e) {
        debugPrint('Error parsing saved theme mode: $e');
        _themeMode = AppThemeMode.system; // Default to system on error
      }
    }
    notifyListeners(); // Notify after loading initial state
  }

  /// Saves the current theme mode to [SharedPreferences].
  Future<void> _saveThemeModeToPrefs(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}