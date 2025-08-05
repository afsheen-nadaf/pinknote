import 'dart:io' show Platform;
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
  static const int _birthdayNotificationId = 2; // ADDED: Birthday notification ID
  static const int _pomodoroRunningId = 100;
  static const int _maxScheduledNotifications = 64; // Max instances to schedule for a recurring item.
  static const int _preEventNotificationOffset = 1000000; // Large offset to ensure pre-event IDs don't collide.


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

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS, permissions are requested separately in _requestPermissions
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin);

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
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("Timezone successfully set via flutter_timezone: $timeZoneName");
    } catch (e) {
      debugPrint("CRITICAL: Failed to get local timezone. Error: $e. Falling back to UTC.");
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
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
  }) async {
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping reminder for '${title.toLowerCase()}' due to permissions.");
      return;
    }
    
    String notificationTitle;
    String notificationBody;

    if (type == 'task') {
      notificationTitle = '🐝 buzz buzz — this task needs a hug (and finishing) right now!';
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
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
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

        if (i == 0 && type == 'event') {
          _schedulePreEventNotification(id, title, nextDate, payload, notificationDetails);
        }

        await _notificationsPlugin.zonedSchedule(
          id + i, // Use a unique ID for each instance in the series
          notificationTitle,
          notificationBody,
          tz.TZDateTime.from(nextDate, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      id, // The base ID is used for the single instance
      notificationTitle,
      notificationBody,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    debugPrint("Scheduled one-time reminder for '$title' at $scheduledDate");
  }

  /// Helper to schedule the 10-minute pre-event reminder
  Future<void> _schedulePreEventNotification(int baseId, String title, DateTime eventDate, String payload, NotificationDetails details) async {
      final preNotificationDateTime = eventDate.subtract(const Duration(minutes: 10));
      if (preNotificationDateTime.isAfter(DateTime.now())) {
        final int preEventId = baseId + _preEventNotificationOffset;
        await _notificationsPlugin.zonedSchedule(
          preEventId,
          'almost time! your event starts in 10 mins ⏳',
          title.toLowerCase(),
          tz.TZDateTime.from(preNotificationDateTime, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      }
  }

  /// Cancels all notifications associated with a given base ID.
  Future<void> cancelNotification(int id) async {
    for (int i = 0; i < _maxScheduledNotifications; i++) {
      await _notificationsPlugin.cancel(id + i);
    }
    await _notificationsPlugin.cancel(id + _preEventNotificationOffset);
    debugPrint("Cancelled all potential notifications for base id: $id");
  }

  Future<void> handleInitialNotification() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
      debugPrint('App launched by notification tap. Payload: $payload');
      await Future.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(payload);
    }
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  bool get isNotificationsEnabled => _notificationsEnabled;

  Future<void> setNotificationPreference(bool enabled, BuildContext context, {String? userName}) async {
    _notificationsEnabled = enabled;
    await _prefs.setBool('notifications_enabled', enabled);
    debugPrint("Notifications enabled set to: $enabled");

    if (enabled) {
      debugPrint("Notifications enabled. Scheduling daily notifications.");
      await scheduleDailyGoodMorningNotification(context, userName: userName);
      await scheduleDailyMoodReminderNotification(context);
    } else {
      await _notificationsPlugin.cancelAll();
      debugPrint("All notifications cancelled due to preference change.");
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? screen = data['screen'];
      if (_navigatorKey?.currentState != null) {
        _navigatorKey!.currentState!.popUntil((route) => route.isFirst);
        switch (screen) {
          case 'tasks':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 1});
            break;
          case 'calendar':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 2});
            break;
          case 'pomodoro':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 3});
            break;
          case 'mood_tracker':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 4});
            break;
          default:
            _navigatorKey!.currentState!.pushReplacementNamed('/home');
            break;
        }
      } else {
        debugPrint("Navigator key is null. Cannot navigate.");
      }
    } catch (e) {
      debugPrint("Error parsing notification payload: $e");
    }
  }

  /// FIX: Correctly requests permissions on both Android and iOS.
  Future<bool> _requestPermissions(BuildContext context) async {
    if (!_notificationsEnabled) {
      debugPrint("Notifications are disabled by user preference. Skipping permission request.");
      return false;
    }
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (android != null) {
          final bool? hasBasicPermission = await android.requestNotificationsPermission();
          if (hasBasicPermission == false) {
              _showPermissionDialog(context, isExactAlarm: false);
              return false;
          }
          final bool? hasExactAlarmPermission = await android.requestExactAlarmsPermission();
          if (hasExactAlarmPermission == false) {
              _showPermissionDialog(context, isExactAlarm: true);
              return false;
          }
          return true;
        }
    } else if (Platform.isIOS) {
        final bool? result = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
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

  Future<void> scheduleDailyGoodMorningNotification(BuildContext context, {String? userName}) async {
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping good morning notification due to permissions.");
      return;
    }
    // MODIFIED: This now correctly uses the passed user name.
    final String name = (userName?.isNotEmpty ?? false) ? userName!.toLowerCase() : 'friend';
    await _notificationsPlugin.zonedSchedule(
      _dailyGoodMorningId,
      'good morning, $name — today’s a fresh page just for you 📖🌸',
      'what will you create today?',
      _nextInstanceOf(8, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_good_morning_channel',
          'daily good morning',
          channelDescription: 'a notification to start your day.',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'screen': 'home'}),
    );
    debugPrint("Daily good morning notification scheduled for 8:00 AM for user: $name");
  }

  Future<void> scheduleDailyMoodReminderNotification(BuildContext context) async {
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping mood reminder notification due to permissions.");
      return;
    }
    await _notificationsPlugin.zonedSchedule(
      _dailyMoodReminderId,
      'sprinkle some love on your day — take a sec to track your mood 🌷',
      "how are you feeling today?",
      _nextInstanceOf(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_mood_reminder_channel',
          'daily mood reminder',
          channelDescription: 'a reminder to track your mood.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'screen': 'mood_tracker'}),
    );
    debugPrint("Daily mood reminder notification scheduled for 8:00 PM.");
  }

  // --- FIXED: Birthday Notification Logic ---

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
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
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
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: jsonEncode({'screen': 'pomodoro'}),
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
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: false),
      ),
      payload: jsonEncode({'screen': 'pomodoro'}),
    );
  }

  Future<void> cancelRunningPomodoroNotification() async {
    await _notificationsPlugin.cancel(_pomodoroRunningId);
  }

  void _showPermissionDialog(BuildContext context, {required bool isExactAlarm}) {
    if (kIsWeb) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(isExactAlarm
              ? 'For timely reminders, please enable the "Alarms & Reminders" permission for this app in your device settings.'
              : 'Please enable notifications for this app in your device settings to receive reminders.'),
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
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  // Isolate entry point for background notification handling
  debugPrint('background notification tapped: ${response.payload}');
}