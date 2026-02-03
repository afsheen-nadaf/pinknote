// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:audioplayers/audioplayers.dart'; // For audio playback
import '../utils/app_constants.dart';
import '../services/services.dart';
import '../services/widget_service.dart'; // *** IMPORTED WIDGET SERVICE ***

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return const Scaffold(
      backgroundColor: Colors.transparent, 
      body: Column(
        children: [
          Spacer(), 
          Center( 
            child: PomodoroTimerWidget(),
          ),
          Spacer(),
        ],
      ),
    );
  }
}

enum PomodoroState {
  working,
  shortBreak,
  longBreak,
  paused,
  stopped,
}

class PomodoroTimerWidget extends StatefulWidget {
  const PomodoroTimerWidget({super.key});

  @override
  State<PomodoroTimerWidget> createState() => _PomodoroTimerWidgetState();
}

class _PomodoroTimerWidgetState extends State<PomodoroTimerWidget>
    with TickerProviderStateMixin {
  static const int _workDuration = 25 * 60;
  static const int _shortBreakDuration = 5 * 60;
  static const int _longBreakDuration = 15 * 60;

  int _currentSeconds = _workDuration;
  PomodoroState _currentState = PomodoroState.stopped;
  Timer? _timer;
  int _pomodoroCount = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AudioPlayer _focusPlayer;
  late AudioPlayer _breakPlayer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _focusPlayer = AudioPlayer();
    _breakPlayer = AudioPlayer();
    _focusPlayer.setReleaseMode(ReleaseMode.loop);
    _breakPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _focusPlayer.dispose();
    _breakPlayer.dispose();
    notificationService.cancelRunningPomodoroNotification();
    super.dispose();
  }

  double get _progress {
    int totalDuration;
    switch (_currentState) {
      case PomodoroState.working:
        totalDuration = _workDuration;
        break;
      case PomodoroState.shortBreak:
        totalDuration = _shortBreakDuration;
        break;
      case PomodoroState.longBreak:
        totalDuration = _longBreakDuration;
        break;
      default:
        return 0.0;
    }
    return 1.0 - (_currentSeconds / totalDuration);
  }

  Color _currentStateColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    switch (_currentState) {
      case PomodoroState.working:
        return AppColors.primaryPink;
      case PomodoroState.shortBreak:
        return AppColors.accentBlue;
      case PomodoroState.longBreak:
        return AppColors.accentGreen;
      case PomodoroState.paused:
        return AppColors.textLight;
      case PomodoroState.stopped:
        return isDarkMode ? AppColors.lightGrey : AppColors.textDark;
    }
  }

  IconData _getCurrentStateIcon() {
    switch (_currentState) {
      case PomodoroState.working:
        return Icons.local_florist;
      case PomodoroState.shortBreak:
        return Icons.local_cafe;
      case PomodoroState.longBreak:
        return Icons.self_improvement;
      case PomodoroState.paused:
        return Icons.hourglass_empty;
      case PomodoroState.stopped:
        return Icons.play_circle_fill;
    }
  }

  void _playMusic() {
    if (_isMuted) return;
    if (_currentState == PomodoroState.working) {
      _breakPlayer.stop();
      _focusPlayer.play(AssetSource('sounds/focus_pomodoro.mp3'));
    } else if (_currentState == PomodoroState.shortBreak ||
        _currentState == PomodoroState.longBreak) {
      _focusPlayer.stop();
      _breakPlayer.play(AssetSource('sounds/break_pomodoro.mp3'));
    }
  }

  void _stopMusic() {
    _focusPlayer.stop();
    _breakPlayer.stop();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _stopMusic();
    } else {
      if (_currentState == PomodoroState.working ||
          _currentState == PomodoroState.shortBreak ||
          _currentState == PomodoroState.longBreak) {
        _playMusic();
      }
    }
  }

  void _startTimer() {
    if (_currentState == PomodoroState.stopped) {
      _currentState = PomodoroState.working;
      _currentSeconds = _workDuration;
    } else if (_currentState == PomodoroState.paused) {
      if (_currentSeconds > _shortBreakDuration && _currentSeconds <= _workDuration) {
          _currentState = PomodoroState.working;
      } else if (_pomodoroCount > 0 && _pomodoroCount % 4 == 0) {
          _currentState = PomodoroState.longBreak;
      } else {
          _currentState = PomodoroState.shortBreak;
      }
    }

    _pulseController.repeat(reverse: true);
    _playMusic();
    
    notificationService.showRunningPomodoroNotification(
      title: 'pomodoro timer running',
      body: 'currently in ${_getCurrentStateLabel()} session. time remaining: ${_formatTime(_currentSeconds)}',
      context: context,
    );
    
    // *** WIDGET UPDATE ***
    WidgetService.updatePomodoroWidget(
      status: _getCurrentStateLabel(), 
      secondsRemaining: _currentSeconds, 
      isRunning: true
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() {
          _currentSeconds--;
        });
        
        // Only update notification/widget periodically to save battery, but for now 1s is fine for accuracy
        notificationService.showRunningPomodoroNotification(
          title: 'pomodoro timer running',
          body: 'currently in ${_getCurrentStateLabel()} session. time remaining: ${_formatTime(_currentSeconds)}',
          context: context,
        );
        
        // *** WIDGET UPDATE ***
        WidgetService.updatePomodoroWidget(
          status: _getCurrentStateLabel(), 
          secondsRemaining: _currentSeconds, 
          isRunning: true
        );

      } else {
        _timer?.cancel();
        _pulseController.stop();
        _moveToNextState();
      }
    });
  }

  void _pauseTimer() {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      _pulseController.stop();
      _stopMusic();
      setState(() {
        _currentState = PomodoroState.paused;
      });
      notificationService.cancelRunningPomodoroNotification();

      // *** WIDGET UPDATE ***
      WidgetService.updatePomodoroWidget(
        status: "Paused", 
        secondsRemaining: _currentSeconds, 
        isRunning: false
      );
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop(canceled: false);
    _stopMusic();
    setState(() {
      _currentSeconds = _workDuration;
      _currentState = PomodoroState.stopped;
      _pomodoroCount = 0;
    });
    notificationService.cancelRunningPomodoroNotification();

    // *** WIDGET UPDATE ***
    WidgetService.updatePomodoroWidget(
      status: "Ready to Focus", 
      secondsRemaining: _workDuration, 
      isRunning: false
    );
  }

  void _moveToNextState() {
    _stopMusic();
    notificationService.cancelRunningPomodoroNotification();

    setState(() {
      if (_currentState == PomodoroState.working) {
        _pomodoroCount++;
        soundService.playPomodoroSessionCompleteSound();
        notificationService.showPomodoroCompletionNotification(
          'pomodoro session complete!',
          'you completed a ${_workDuration ~/ 60}-minute focus session. take a break, you deserve it <3',
        );

        if (_pomodoroCount > 0 && _pomodoroCount % 4 == 0) {
          _currentState = PomodoroState.longBreak;
          _currentSeconds = _longBreakDuration;
        } else {
          _currentState = PomodoroState.shortBreak;
          _currentSeconds = _shortBreakDuration;
        }
      } else {
        _currentState = PomodoroState.working;
        _currentSeconds = _workDuration;
      }
      _startTimer();
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  String _getCurrentStateLabel() {
    switch (_currentState) {
      case PomodoroState.working:
        return 'focus';
      case PomodoroState.shortBreak:
        return 'quick recharge';
      case PomodoroState.longBreak:
        return 'stretch & breathe';
      case PomodoroState.paused:
        return 'on pause';
      case PomodoroState.stopped:
        return "let's get started!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _currentStateColor(context);
    final bool isRunning = _currentState == PomodoroState.working ||
        _currentState == PomodoroState.shortBreak ||
        _currentState == PomodoroState.longBreak;

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Card(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(color: AppColors.borderLight.withOpacity(0.3), width: 1),
        ),
        elevation: 12.0,
        shadowColor: AppColors.shadowSoft.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getCurrentStateLabel(),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 30),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isRunning ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                        ),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 8,
                              backgroundColor: AppColors.borderLight.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatTime(_currentSeconds),
                                style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w300, color: color),
                              ),
                              const SizedBox(height: 8),
                              Icon(_getCurrentStateIcon(), color: color.withOpacity(0.8), size: 24),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: isRunning ? _pauseTimer : _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning ? AppColors.secondaryPink : AppColors.primaryPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 6,
                        shadowColor: AppColors.primaryPink.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 22),
                          const SizedBox(width: 8),
                          Text(isRunning ? 'pause' : 'start', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                       onPressed: _toggleMute,
                       style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor: theme.colorScheme.onSecondaryContainer,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                          elevation: 6,
                          shadowColor: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                       ),
                       child: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                   Expanded(
                    child: ElevatedButton(
                      onPressed: _resetTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 6,
                        shadowColor: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('reset', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _moveToNextState,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                        shadowColor: AppColors.accentBlue.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.skip_next_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('skip', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryPink),
                    const SizedBox(width: 10),
                    Text(
                      'completed sessions: $_pomodoroCount',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}