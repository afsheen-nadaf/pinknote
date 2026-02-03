import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _pomodoroProvider = 'PomodoroWidgetProvider';

  static Future<void> updatePomodoroWidget({
    required String status,
    required int secondsRemaining,
    required bool isRunning,
  }) async {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    
    // Saves status in lowercase (e.g., "focus", "quick recharge") to match Kotlin logic
    await HomeWidget.saveWidgetData('pomo_status', status.toLowerCase());
    await HomeWidget.saveWidgetData('pomo_time', '$minutes:$seconds');
    await HomeWidget.saveWidgetData('pomo_is_running', isRunning);
    
    await HomeWidget.updateWidget(androidName: _pomodoroProvider);
  }
  
  static Future<void> resetPomodoroWidget() async {
    await HomeWidget.saveWidgetData('pomo_status', 'focus');
    await HomeWidget.saveWidgetData('pomo_time', '25:00');
    await HomeWidget.saveWidgetData('pomo_is_running', false);
    await HomeWidget.updateWidget(androidName: _pomodoroProvider);
  }
}