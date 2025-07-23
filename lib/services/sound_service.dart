import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to manage and play sound effects throughout the app.
class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _isSoundEnabled = true;
  static const String _soundPrefKey = 'sound_effects_enabled';

  /// Returns true if sound effects are currently enabled.
  bool get isSoundEnabled => _isSoundEnabled;

  /// Constructor initializes the service by loading user preferences.
  SoundService() {
    loadSoundPreference();
  }

  /// Loads the user's sound preference from shared preferences.
  Future<void> loadSoundPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool(_soundPrefKey) ?? true;
      debugPrint('Sound preference loaded: $_isSoundEnabled');
    } catch (e) {
      debugPrint('Error loading sound preference: $e');
    }
  }

  /// Saves the user's sound preference.
  Future<void> setSoundPreference(bool isEnabled) async {
    _isSoundEnabled = isEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundPrefKey, isEnabled);
      debugPrint('Sound preference set to: $_isSoundEnabled');
    } catch (e) {
      debugPrint('Error saving sound preference: $e');
    }
  }

  /// Plays a sound from the given asset path if sounds are enabled.
  void _playSound(String assetPath) {
    if (_isSoundEnabled) {
      try {
        _player.play(AssetSource(assetPath));
      } catch (e) {
        debugPrint('Error playing sound $assetPath: $e');
      }
    }
  }

  // --- Public methods for specific app sounds ---
  // NOTE: You must have these sound files in your `assets/sounds/` directory.

  void playModalOpeningSound() => _playSound('sounds/modal_opening.mp3');

  // FIX: Re-enabled this sound as requested.
  void playAddTaskSound() => _playSound('sounds/add_task.mp3');

  void playMarkAsImportantSound() => _playSound('sounds/mark_as_important.mp3');
  void playSwipeDeleteSound() => _playSound('sounds/swipe_delete.mp3');
  void playPomodoroSessionCompleteSound() => _playSound('sounds/pomodoro_session_complete.mp3');
  void playTaskCompletedSound() => _playSound('sounds/task_completed.mp3');

  // FIX: Implemented the badge unlocked sound.
  void playBadgeUnlockedSound() => _playSound('sounds/badge_unlocked.mp3');

  // FIX: Added sounds for the pomodoro timer.
  void playPomodoroFocusSound() => _playSound('sounds/focus_pomodoro.mp3');
  void playPomodoroBreakSound() => _playSound('sounds/break_pomodoro.mp3');
}