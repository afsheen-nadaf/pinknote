import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_settings/app_settings.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'dart:convert'; // Import for JSON encoding/decoding

/// A service class to handle local notifications in the Flutter application.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  late SharedPreferences _prefs; // SharedPreferences instance
  bool _notificationsEnabled = true; // Default to true
  GlobalKey<NavigatorState>? _navigatorKey; // Navigator key for redirection

  // Notification IDs
  static const int _dailyGoodMorningId = 0;
  static const int _dailyMoodReminderId = 1;
  static const int _pomodoroRunningId = 100;

  /// Initializes the notification plugin with platform-specific settings.
  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      // Attempt to set the local timezone dynamically
      tz.setLocalLocation(tz.getLocation(tz.local.name));
    } catch (e) {
      debugPrint("Could not set local timezone automatically: $e");
      // Fallback to a default timezone if the local one isn't found
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    // Load notification preference
    _prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    debugPrint("Notifications initially enabled: $_notificationsEnabled");


    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
        debugPrint('Notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Setter for the navigator key. This allows the service to navigate.
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Getter for notification enabled status.
  bool get isNotificationsEnabled => _notificationsEnabled;

  /// Sets the notification preference and saves it.
  /// If notifications are disabled, all pending notifications are cancelled.
  Future<void> setNotificationPreference(bool enabled) async {
    _notificationsEnabled = enabled;
    await _prefs.setBool('notifications_enabled', enabled);
    debugPrint("Notifications enabled set to: $enabled");
    if (!enabled) {
      await _notificationsPlugin.cancelAll();
      debugPrint("All notifications cancelled due to preference change.");
    }
    // Note: Re-scheduling daily notifications when re-enabled will be handled
    // by the calling widget (e.g., SettingsScreen or MainAppScreen) as it requires BuildContext.
  }

  /// Handles navigation based on the notification payload.
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? screen = data['screen'];
      final String? id = data['id']; // For task/event ID

      debugPrint('Navigating to screen: $screen with ID: $id');

      if (_navigatorKey?.currentState != null) {
        // Pop existing routes until home, then push the specific screen
        _navigatorKey!.currentState!.popUntil((route) => route.isFirst);

        switch (screen) {
          case 'tasks':
            // Assuming TasksScreen is at index 1 in MainAppScreen's IndexedStack
            // This requires a way to change the selected index of MainAppScreen
            // A more robust solution would be to use a Navigator 2.0 or a shared state.
            // For now, we'll just navigate to the main app screen, and the user can go to tasks.
            // If direct deep linking is needed, MainAppScreen would need a method to change its selected index.
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 1}); // Example
            break;
          case 'calendar':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 2}); // Example
            break;
          case 'pomodoro':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 3}); // Example
            break;
          case 'mood_tracker':
            _navigatorKey!.currentState!.pushReplacementNamed('/home', arguments: {'initialIndex': 4}); // Example
            break;
          default:
            // Navigate to home screen if payload is unknown or not handled
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


  /// Requests necessary permissions for notifications, especially for exact alarms on Android.
  /// Returns true if permissions are granted, false otherwise.
  Future<bool> _requestPermissions(BuildContext context) async {
    if (!_notificationsEnabled) {
      debugPrint("Notifications are disabled by user preference. Skipping permission request.");
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool? permissionGranted = false;
    try {
      permissionGranted = await androidImplementation?.requestExactAlarmsPermission();
      if (permissionGranted == true) {
        debugPrint("Exact alarm permission granted.");
      } else {
        debugPrint("Exact alarm permission NOT granted.");
        // Show a user-friendly dialog if permission is not granted
        _showPermissionDialog(context);
      }
    } catch (e) {
      debugPrint("Error requesting exact alarm permission: $e");
      // If an error occurs (e.g., PlatformException), still show the dialog
      _showPermissionDialog(context);
    }
    return permissionGranted ?? false;
  }

  /// Helper to get the next instance of a specific time.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedules a daily "Good Morning" notification.
  Future<void> scheduleDailyGoodMorningNotification(BuildContext context) async {
    if (!_notificationsEnabled) {
      debugPrint("Skipping good morning notification due to user preference.");
      return;
    }
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping good morning notification due to permissions.");
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_good_morning_channel',
      'daily good morning',
      channelDescription: 'a notification to start your day.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.zonedSchedule(
      _dailyGoodMorningId,
      'good morning! ☀️',
      'time to get started with your day and be productive!',
      // FIX: Changed schedule time to 9:00 AM to better accommodate timezone issues.
      _nextInstanceOf(9, 0),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'screen': 'home'}), // Payload for redirection
    );
    debugPrint("Daily good morning notification scheduled for 9:00 AM.");
  }

  /// Schedules a daily mood tracking reminder.
  Future<void> scheduleDailyMoodReminderNotification(BuildContext context) async {
    if (!_notificationsEnabled) {
      debugPrint("Skipping mood reminder notification due to user preference.");
      return;
    }
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping mood reminder notification due to permissions.");
      return;
    }
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_mood_reminder_channel',
      'daily mood reminder',
      channelDescription: 'a reminder to track your mood.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      _dailyMoodReminderId,
      'how are you feeling?',
      "don't forget to track your mood today <3",
      // FIX: Changed schedule time to 9:00 PM to better accommodate timezone issues.
      _nextInstanceOf(21, 0),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'screen': 'mood_tracker'}), // Payload for redirection
    );
    debugPrint("Daily mood reminder notification scheduled for 9:00 PM.");
  }

  /// Schedules a one-time reminder for a task or event.
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required BuildContext context, // Added BuildContext
    required String type, // 'task' or 'event'
  }) async {
    if (!_notificationsEnabled) {
      debugPrint("Skipping reminder notification for '${title.toLowerCase()}' due to user preference.");
      return;
    }
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping reminder notification for '${title.toLowerCase()}' due to permissions.");
      return;
    }

    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint("Attempted to schedule a notification for '${title.toLowerCase()}' in the past. aborting.");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'reminders',
      channelDescription: 'notifications for tasks and events.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title.toLowerCase(), // Ensure title is lowercase
      body.toLowerCase(), // Ensure body is lowercase
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'type': type, 'id': id.toString(), 'screen': type == 'task' ? 'tasks' : 'calendar'}), // Payload for redirection
    );
    debugPrint("Scheduled reminder for '${title.toLowerCase()}' at $scheduledDate");
  }

  /// Cancels a scheduled notification by its ID.
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint("Cancelled notification with id: $id");
  }

  /// Shows a notification when a Pomodoro session is completed.
  Future<void> showPomodoroCompletionNotification(String title, String body) async {
    if (!_notificationsEnabled) {
      debugPrint("Skipping pomodoro completion notification due to user preference.");
      return;
    }
    // This notification is not time-sensitive, so it doesn't need exact alarm permission check here
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pomodoro_completion_channel',
      'pomodoro complete',
      channelDescription: 'notification for when a pomodoro session ends.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title.toLowerCase(), // Ensure title is lowercase
      body.toLowerCase(), // Ensure body is lowercase
      platformDetails,
      payload: jsonEncode({'screen': 'pomodoro'}), // Payload for redirection
    );
  }

  /// Shows a persistent notification that the Pomodoro timer is running.
  Future<void> showRunningPomodoroNotification({
    required String title,
    required String body,
    required BuildContext context,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint("Skipping running pomodoro notification due to user preference.");
      return;
    }
    // This is a persistent notification, but still benefits from exact alarm permission for reliability
    if (!await _requestPermissions(context)) {
      debugPrint("Skipping running pomodoro notification due to permissions.");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pomodoro_running_channel',
      'pomodoro running',
      channelDescription: 'persistent notification while the timer is active.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      _pomodoroRunningId,
      title.toLowerCase(), // Ensure title is lowercase
      body.toLowerCase(), // Ensure body is lowercase
      platformDetails,
      payload: jsonEncode({'screen': 'pomodoro'}), // Payload for redirection
    );
  }

  /// Cancels the persistent "Pomodoro running" notification.
  Future<void> cancelRunningPomodoroNotification() async {
    await _notificationsPlugin.cancel(_pomodoroRunningId);
  }

  /// Displays a dialog to the user about the exact alarm permission.
  void _showPermissionDialog(BuildContext context) {
    debugPrint('exact alarm permission not granted. please enable it in app settings.');
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('permission required'),
          content: const Text(
              'for timely reminders and alarms, please enable "alarms & reminders" permission for pinknote in your device settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('open settings'),
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
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  debugPrint('background notification tapped: ${notificationResponse.payload}');
  // This function runs in an isolated scope, so it cannot directly access
  // the Navigator. You would typically use platform channels or
  // a global event bus to communicate with the main Flutter isolate.
  // For this example, we'll just log it.
  // The main app's onDidReceiveNotificationResponse handles foreground/tapped-from-tray.
}