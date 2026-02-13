import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_settings/app_settings.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_timezone/flutter_timezone.dart';

/// A service class to handle local notifications in the Flutter application.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  late SharedPreferences _prefs;
  bool _notificationsEnabled = true;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Notification IDs
  static const int _dailyGoodMorningId = 0;
  static const int _dailyMoodReminderId = 1;
  static const int _birthdayNotificationId = 2;
  static const int _pomodoroRunningId = 100;
  static const int _maxScheduledNotifications = 64;
  static const int _preEventNotificationOffset = 1000000;


  /// Generates a stable, positive 31-bit integer ID from a string.
  /// This is safer than .hashCode, which is not guaranteed to be stable across app restarts.
  static int createIntIdFromString(String id) {
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = 31 * hash + id.codeUnitAt(i);
    }
    // Mask to get a 31-bit positive integer.
    return hash & 0x7FFFFFFF;
  }

  /// Initializes the notification plugin with platform-specific settings.
  Future<void> init() async {
    await _initializeTimezone();

    _prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    debugPrint("Notifications initially enabled: $_notificationsEnabled");

    // ✅ FIXED: Use @drawable/ic_notification instead of @mipmap/ic_launcher
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification tapped while app is running: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Sets the local timezone using the reliable flutter_timezone package.
  Future<void> _initializeTimezone() async {
    try {
      tz.initializeTimeZones();
      // flutter_timezone 5.x - cast to String
      final timeZoneName = (await FlutterTimezone.getLocalTimezone()
          .timeout(const Duration(seconds: 3))) as String;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("Timezone successfully set via flutter_timezone: $timeZoneName");
    } catch (e) {
      debugPrint("Timezone error: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Schedules a reminder for a task or event, with robust support for recurrence.
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required BuildContext context,
    required String type,
    String? recurrenceUnit,
    int? recurrenceValue,
    DateTime? eventEndDate,
  }) async {
    // ✅ FIXED: Check if notifications are globally disabled FIRST
    if (!_notificationsEnabled) {
      debugPrint("Skipping reminder for '${title.toLowerCase()}' - notifications are disabled.");
      return;
    }
    
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping reminder for '${title.toLowerCase()}' due to permissions.");
      return;
    }
    
    String notificationTitle;
    String notificationBody;

    if (type == 'task') {
      notificationTitle = '🐝 buzz buzz - this task needs a hug (and finishing) right now!';
      notificationBody = title.toLowerCase();
    } else { // 'event'
      notificationTitle = '🐣 psst... your event just started!';
      notificationBody = title.toLowerCase();
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel', 'reminders',
        channelDescription: 'notifications for tasks and events.',
        importance: Importance.high, priority: Priority.high,
        icon: '@drawable/ic_notification',
      ),
    );
    final payload = jsonEncode({'screen': type == 'task' ? 'tasks' : 'calendar'});

    // --- RECURRENCE LOGIC ---
    if (recurrenceUnit != null && recurrenceUnit.isNotEmpty) {
      debugPrint("Scheduling recurring notification for '$title'. Unit: $recurrenceUnit, Value: $recurrenceValue");
      for (int i = 0; i < _maxScheduledNotifications; i++) {
        DateTime? nextDate;
        final int val = recurrenceValue ?? 1;

        switch (recurrenceUnit) {
          case 'minute':
            nextDate = scheduledDate.add(Duration(minutes: i * val));
            break;
          case 'hour':
            nextDate = scheduledDate.add(Duration(hours: i * val));
            break;
          case 'day':
            nextDate = scheduledDate.add(Duration(days: i * val));
            break;
          case 'week':
            nextDate = scheduledDate.add(Duration(days: i * val * 7));
            break;
          case 'month':
            nextDate = DateTime(scheduledDate.year, scheduledDate.month + (i * val), scheduledDate.day, scheduledDate.hour, scheduledDate.minute);
            break;
          case 'year':
            nextDate = DateTime(scheduledDate.year + (i * val), scheduledDate.month, scheduledDate.day, scheduledDate.hour, scheduledDate.minute);
            break;
        }

        if (nextDate == null || nextDate.isBefore(DateTime.now())) {
          continue; // Skip past or invalid dates
        }

        // Stop scheduling recurring events if they are past their end date.
        if (type == 'event' && eventEndDate != null && nextDate.isAfter(eventEndDate)) {
          debugPrint("Stopping recurring schedule for '$title' as it has passed the event's end date.");
          break;
        }

        if (i == 0 && type == 'event') {
          _schedulePreEventNotification(id, title, nextDate, payload, notificationDetails);
        }

        await _notificationsPlugin.zonedSchedule(
          id + i,
          notificationTitle,
          notificationBody,
          tz.TZDateTime.from(nextDate, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }
      return;
    }

    // --- NON-RECURRING LOGIC ---
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint("Attempted to schedule a non-recurring notification for '$title' in the past. Aborting.");
      return;
    }

    if (type == 'event') {
      _schedulePreEventNotification(id, title, scheduledDate, payload, notificationDetails);
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      notificationTitle,
      notificationBody,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    debugPrint("Scheduled ${type == 'task' ? 'task' : 'event'} notification for '$title' at $scheduledDate.");
  }

  /// Schedules a notification 15 minutes before an event starts.
  void _schedulePreEventNotification(
    int baseId,
    String title,
    DateTime eventStart,
    String payload,
    NotificationDetails details,
  ) {
    final preEventTime = eventStart.subtract(const Duration(minutes: 15));

    if (preEventTime.isBefore(DateTime.now())) {
      debugPrint("Skipping pre-event notification for '$title' as it would be in the past.");
      return;
    }

    _notificationsPlugin.zonedSchedule(
      baseId + _preEventNotificationOffset,
      '⏰ heads up!',
      '${title.toLowerCase()} starts in 15 minutes',
      tz.TZDateTime.from(preEventTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    debugPrint("Scheduled pre-event notification for '$title' at $preEventTime.");
  }

  /// Cancels a reminder notification by ID.
  Future<void> cancelReminderNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    await _notificationsPlugin.cancel(id + _preEventNotificationOffset);
    debugPrint("Cancelled reminder notification with ID: $id");
  }

  /// Cancels ALL pending notifications.
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("Cancelled all pending notifications.");
  }

  /// Returns whether notifications are globally enabled.
  bool get areNotificationsEnabled => _notificationsEnabled;

  /// Enables or disables all notifications.
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _prefs.setBool('notifications_enabled', enabled);
    debugPrint("Notifications ${enabled ? 'enabled' : 'disabled'} globally.");
    
    // ✅ FIXED: Cancel all notifications when disabling
    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  /// Backward compatibility wrapper for isNotificationsEnabled
  bool isNotificationsEnabled() => _notificationsEnabled;

  /// Backward compatibility wrapper for setNotificationPreference
  Future<void> setNotificationPreference(bool enabled) async {
    await setNotificationsEnabled(enabled);
  }

  /// Backward compatibility wrapper for cancelNotification (single notification)
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint("Cancelled notification with id=$id");
  }

  Future<bool> _requestPermissions(BuildContext context) async {
    if (kIsWeb) return true;

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? grantedNotifications = await androidImplementation.requestNotificationsPermission();
      debugPrint("Notification permission granted: $grantedNotifications");

      if (grantedNotifications != true) {
        if (context.mounted) _showPermissionDialog(context);
        return false;
      }

      final bool? grantedExactAlarms = await androidImplementation.requestExactAlarmsPermission();
      debugPrint("Exact alarm permission granted: $grantedExactAlarms");

      if (grantedExactAlarms != true) {
        debugPrint("Exact alarms not granted, but proceeding with inexact scheduling.");
      }

      return true;
    }
    return false;
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyGoodMorningNotification(BuildContext context, {String name = ''}) async {
    // ✅ FIXED: Check if notifications are enabled
    if (!_notificationsEnabled) {
      debugPrint("Skipping good morning notification - notifications are disabled.");
      return;
    }
    
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping good morning notification due to permissions.");
      return;
    }

    final String userName = (name.isNotEmpty) ? name.toLowerCase() : 'friend';

    await _notificationsPlugin.zonedSchedule(
      _dailyGoodMorningId,
      'good morning, $userName - today\'s a fresh page just for you 📖🌸',
      'what will you create today?',
      _nextInstanceOf(8, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_good_morning_channel',
          'daily good morning',
          channelDescription: 'a notification to start your day.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint("Daily good morning notification scheduled for 8:00 AM for user: $userName");
  }

  Future<void> scheduleDailyMoodReminderNotification(BuildContext context) async {
    // ✅ FIXED: Check if notifications are enabled
    if (!_notificationsEnabled) {
      debugPrint("Skipping mood reminder notification - notifications are disabled.");
      return;
    }
    
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping mood reminder notification due to permissions.");
      return;
    }
    await _notificationsPlugin.zonedSchedule(
      _dailyMoodReminderId,
      'sprinkle some love on your day - take a sec to track your mood 🌷',
      "how are you feeling today?",
      _nextInstanceOf(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_mood_reminder_channel',
          'daily mood reminder',
          channelDescription: 'a reminder to track your mood.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint("Daily mood reminder notification scheduled for 8:00 PM.");
  }

  // --- Birthday Notification Logic ---

  /// Calculates the next birthday instance.
  tz.TZDateTime _nextBirthday(DateTime birthDate) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Schedule for 9 AM on the birth date
    tz.TZDateTime nextBirthdayDate = tz.TZDateTime(tz.local, now.year, birthDate.month, birthDate.day, 9);

    // If the birthday this year has already passed, schedule for next year.
    if (nextBirthdayDate.isBefore(now)) {
      nextBirthdayDate = tz.TZDateTime(tz.local, now.year + 1, birthDate.month, birthDate.day, 9);
    }
    return nextBirthdayDate;
  }

  /// Schedules a yearly notification for the user's birthday.
  Future<void> scheduleBirthdayNotification({
    required BuildContext context,
    required String userName,
    required DateTime birthDate,
  }) async {
    // ✅ FIXED: Check if notifications are enabled
    if (!_notificationsEnabled) {
      debugPrint("Skipping birthday notification - notifications are disabled.");
      return;
    }
    
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping birthday notification due to permissions.");
      return;
    }

    final String name = (userName.isNotEmpty) ? userName.toLowerCase() : 'friend';

    await _notificationsPlugin.zonedSchedule(
      _birthdayNotificationId,
      'happy birthday, $name! 🎉🎂',
      'wishing you a fantastic day filled with joy and laughter!',
      _nextBirthday(birthDate),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday_channel',
          'birthdays',
          channelDescription: 'get a special message on your birthday.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint("Birthday notification scheduled for ${birthDate.month}/${birthDate.day} at 9:00 AM.");
  }

  /// Cancels the scheduled birthday notification.
  Future<void> cancelBirthdayNotification() async {
    await _notificationsPlugin.cancel(_birthdayNotificationId);
    debugPrint("Cancelled birthday notification.");
  }

  Future<void> showPomodoroCompletionNotification(String title, String body) async {
    if (!_notificationsEnabled) return;
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title.toLowerCase(),
      body.toLowerCase(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pomodoro_completion_channel',
          'pomodoro complete',
          channelDescription: 'notification for when a pomodoro session ends.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  Future<void> showRunningPomodoroNotification({
    required String title,
    required String body,
    required BuildContext context,
  }) async {
    if (!await _requestPermissions(context)) return;
    await _notificationsPlugin.show(
      _pomodoroRunningId,
      title.toLowerCase(),
      body.toLowerCase(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pomodoro_running_channel',
          'pomodoro running',
          channelDescription: 'persistent notification while the timer is active.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  Future<void> cancelRunningPomodoroNotification() async {
    await _notificationsPlugin.cancel(_pomodoroRunningId);
  }

  void _showPermissionDialog(BuildContext context) {
    if (kIsWeb) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('please enable notifications for this app in your device settings to receive reminders.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                AppSettings.openAppSettings(type: AppSettingsType.notification);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload);
      final screen = data['screen'];
      
      if (_navigatorKey?.currentState != null) {
        switch (screen) {
          case 'home':
            _navigatorKey!.currentState!.pushReplacementNamed('/home');
            break;
          case 'tasks':
            _navigatorKey!.currentState!.pushReplacementNamed('/tasks');
            break;
          case 'calendar':
            _navigatorKey!.currentState!.pushReplacementNamed('/calendar');
            break;
          case 'mood_tracker':
            _navigatorKey!.currentState!.pushReplacementNamed('/mood_tracker');
            break;
          case 'pomodoro':
            _navigatorKey!.currentState!.pushReplacementNamed('/pomodoro');
            break;
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  // Isolate entry point for background notification handling
  debugPrint('background notification tapped: ${response.payload}');
}