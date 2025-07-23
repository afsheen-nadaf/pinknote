// This file acts as a central hub for all the services in the app.
// It exports the service classes and provides singleton instances
// that can be easily accessed from anywhere in the app.

// Export service classes to make them available for type annotations
// elsewhere in the app without needing to import the specific file.
export 'firestore_service.dart';
export 'notification_service.dart';
export 'sound_service.dart';

// Import the service classes to create instances.
import 'notification_service.dart';
import 'sound_service.dart';

// Create singleton instances of the services.
// These global variables are used to access service methods.
// For example: `notificationService.scheduleReminderNotification(...)`
final NotificationService notificationService = NotificationService();
final SoundService soundService = SoundService();
