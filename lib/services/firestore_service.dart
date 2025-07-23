import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' hide Category; // Hide Category from foundation to resolve ambiguous import
import '../models/task.dart';
import '../models/category.dart';
import '../models/event.dart';
import '../models/mood_entry.dart'; // New: Import MoodEntry and PersonalNote models

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _appId;
  String? _userId;

  FirestoreService(this._appId);

  /// Sets the user ID for Firestore operations.
  /// This method should be called after successful user authentication.
  void setUserId(String userId) {
    _userId = userId;
  }

  // --- Collection References ---

  /// Returns the Firestore collection reference for tasks specific to the current user.
  /// Throws an exception if the user ID is not set.
  CollectionReference<Map<String, dynamic>> _getTasksCollectionRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for tasks. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/tasks
    return _firestore.collection('artifacts/$_appId/users/$_userId/tasks');
  }

  /// Returns the Firestore collection reference for categories specific to the current user.
  /// Throws an exception if the user ID is not set.
  CollectionReference<Map<String, dynamic>> _getCategoriesCollectionRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for categories. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/categories
    return _firestore.collection('artifacts/$_appId/users/$_userId/categories');
  }

  /// Returns the Firestore collection reference for events specific to the current user.
  /// Throws an exception if the user ID is not set.
  CollectionReference<Map<String, dynamic>> _getEventsCollectionRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for events. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/events
    return _firestore.collection('artifacts/$_appId/users/$_userId/events');
  }

  /// Returns the Firestore document reference for user-specific data like badges and profile info.
  /// Throws an exception if the user ID is not set.
  DocumentReference<Map<String, dynamic>> _getUserDataDocRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for user data. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/user_data/profile
    return _firestore.collection('artifacts/$_appId/users/$_userId/user_data').doc('profile');
  }

  /// Returns the Firestore collection reference for mood entries specific to the current user.
  CollectionReference<Map<String, dynamic>> _getMoodEntriesCollectionRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for mood entries. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/mood_entries
    return _firestore.collection('artifacts/$_appId/users/$_userId/mood_entries');
  }

  /// Returns the Firestore collection reference for personal notes specific to the current user.
  CollectionReference<Map<String, dynamic>> _getPersonalNotesCollectionRef() {
    if (_userId == null) {
      throw Exception("User ID is not available for personal notes. Call setUserId() first.");
    }
    // Path: artifacts/{appId}/users/{userId}/personal_notes
    return _firestore.collection('artifacts/$_appId/users/$_userId/personal_notes');
  }

  // --- Task Operations ---

  /// Retrieves a real-time stream of tasks for the current user.
  /// Tasks are ordered by their 'order' field.
  Stream<List<Task>> getTasks() {
    if (_userId == null) {
      debugPrint("getTasks: User ID is null, returning empty stream.");
      return Stream.value([]); // Return empty list if not authenticated yet
    }
    return _getTasksCollectionRef().orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  /// Adds a new task to Firestore for the current user.
  Future<void> addTask(Task newTask) async {
    if (_userId == null) {
      debugPrint("addTask: User ID is null, cannot add task.");
      return;
    }
    try {
      await _getTasksCollectionRef().doc(newTask.id).set(newTask.toFirestore());
      debugPrint('Task added: ${newTask.title}');
    } catch (e) {
      debugPrint('Error adding task: $e');
      rethrow; // Re-throw to be handled by UI
    }
  }

  /// Updates an existing task in Firestore for the current user.
  Future<void> updateTask(Task updatedTask) async {
    if (_userId == null) {
      debugPrint("updateTask: User ID is null, cannot update task.");
      return;
    }
    try {
      final docRef = _getTasksCollectionRef().doc(updatedTask.id);
      await docRef.update(updatedTask.toFirestore());
      debugPrint('Task updated: ${updatedTask.title}');
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  /// Toggles the completion status of a task.
  Future<void> toggleTaskComplete(String taskId, bool isCompleted) async {
    if (_userId == null) {
      debugPrint("toggleTaskComplete: User ID is null, cannot toggle task completion.");
      return;
    }
    try {
      // FIX: The boolean passed in (`isCompleted`) is the NEW desired state.
      // We should use it directly instead of negating it again.
      await _getTasksCollectionRef().doc(taskId).update({'isCompleted': isCompleted});
      debugPrint('Task completion toggled for ID: $taskId');
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
      rethrow;
    }
  }

  /// Toggles the importance status of a task.
  Future<void> toggleTaskImportance(String taskId, bool isImportant) async {
    if (_userId == null) {
      debugPrint("toggleTaskImportance: User ID is null, cannot toggle task importance.");
      return;
    }
    try {
      await _getTasksCollectionRef().doc(taskId).update({'isImportant': isImportant});
      debugPrint('Task importance toggled for ID: $taskId to $isImportant');
    } catch (e) {
      debugPrint('Error toggling task importance: $e');
      rethrow;
    }
  }

  /// Toggles the completion status of a specific subtask within a task.
  Future<void> toggleSubtaskComplete(String taskId, int subtaskIndex) async {
    if (_userId == null) {
      debugPrint("toggleSubtaskComplete: User ID is null, cannot toggle subtask completion.");
      return;
    }
    try {
      final taskDocRef = _getTasksCollectionRef().doc(taskId);
      final taskDoc = await taskDocRef.get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data();
        if (taskData != null && taskData['subtasks'] is List) {
          List<dynamic> subtasksJson = List.from(taskData['subtasks']);
          if (subtaskIndex >= 0 && subtaskIndex < subtasksJson.length) {
            subtasksJson[subtaskIndex]['isCompleted'] = !subtasksJson[subtaskIndex]['isCompleted'];
            await taskDocRef.update({'subtasks': subtasksJson});
            debugPrint('Subtask completion toggled for Task ID: $taskId, Subtask Index: $subtaskIndex');
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling subtask completion: $e');
      rethrow;
    }
  }

  /// Deletes a task from Firestore for the current user.
  Future<void> deleteTask(String taskId) async {
    if (_userId == null) {
      debugPrint("deleteTask: User ID is null, cannot delete task.");
      return;
    }
    try {
      await _getTasksCollectionRef().doc(taskId).delete();
      debugPrint('Task deleted: $taskId');
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  /// Updates the order of tasks in Firestore.
  Future<void> reorderTasks(List<Task> tasks) async {
    if (_userId == null) {
      debugPrint("reorderTasks: User ID is null, cannot reorder tasks.");
      return;
    }
    final batch = _firestore.batch();
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final taskRef = _getTasksCollectionRef().doc(task.id);
      batch.update(taskRef, {'order': i});
    }
    try {
      await batch.commit();
      debugPrint('Tasks reordered successfully.');
    } catch (e) {
      debugPrint('Error reordering tasks: $e');
      rethrow;
    }
  }

  // --- Category Operations ---

  /// Retrieves a real-time stream of categories for the current user.
  Stream<List<Category>> getCategories() {
    if (_userId == null) {
      debugPrint("getCategories: User ID is null, returning empty stream.");
      return Stream.value([]);
    }
    return _getCategoriesCollectionRef().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
    });
  }

  /// Adds a new category to Firestore for the current user.
  Future<void> addCategory(Category newCategory) async {
    if (_userId == null) {
      debugPrint("addCategory: User ID is null, cannot add category.");
      return;
    }
    try {
      await _getCategoriesCollectionRef().doc(newCategory.id).set(newCategory.toFirestore());
      debugPrint('Category added: ${newCategory.name}');
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  /// Updates an existing category in Firestore for the current user.
  Future<void> updateCategory(Category updatedCategory) async {
    if (_userId == null) {
      debugPrint("updateCategory: User ID is null, cannot update category.");
      return;
    }
    try {
      await _getCategoriesCollectionRef().doc(updatedCategory.id).update(updatedCategory.toFirestore());
      debugPrint('Category updated: ${updatedCategory.name}');
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  /// Deletes a category and moves its tasks to 'General'.
  Future<void> deleteCategory(String categoryId) async {
    if (_userId == null) {
      debugPrint("deleteCategory: User ID is null, cannot delete category.");
      return;
    }
    final batch = _firestore.batch();
    try {
      final categoryDoc = await _getCategoriesCollectionRef().doc(categoryId).get();
      final categoryName = categoryDoc.data()?['name'] as String?;

      if (categoryName != null) {
        final tasksToUpdate = await _getTasksCollectionRef()
            .where('category', isEqualTo: categoryName)
            .get();

        for (var taskDoc in tasksToUpdate.docs) {
          batch.update(taskDoc.reference, {'category': 'general'});
        }
      }

      batch.delete(_getCategoriesCollectionRef().doc(categoryId));

      await batch.commit();
      debugPrint('Category $categoryId deleted and associated tasks moved to general.');
    } catch (e) {
      debugPrint('Error deleting category or updating associated tasks: $e');
      rethrow;
    }
  }

  // --- Event Operations ---

  /// Retrieves a real-time stream of events for the current user.
  Stream<List<Event>> getEvents() {
    if (_userId == null) {
      debugPrint("getEvents: User ID is null, returning empty stream.");
      return Stream.value([]);
    }
    return _getEventsCollectionRef().snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    });
  }

  /// Adds a new event to Firestore for the current user.
  Future<void> addEvent(Event newEvent) async {
    if (_userId == null) {
      debugPrint("addEvent: User ID is null, cannot add event.");
      return;
    }
    try {
      await _getEventsCollectionRef().doc(newEvent.id).set(newEvent.toFirestore());
      debugPrint('Event added: ${newEvent.title}');
    } catch (e) {
      debugPrint('Error adding event: $e');
      rethrow;
    }
  }

  /// Updates an existing event in Firestore for the current user.
  Future<void> updateEvent(Event updatedEvent) async {
    if (_userId == null) {
      debugPrint("updateEvent: User ID is null, cannot update event.");
      return;
    }
    try {
      final docRef = _getEventsCollectionRef().doc(updatedEvent.id);
      // Check if the document exists before attempting to update
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.update(updatedEvent.toFirestore());
        debugPrint('Event updated: ${updatedEvent.title}');
      } else {
        debugPrint('Error updating event: Document with ID ${updatedEvent.id} not found. Creating new document.');
        // If document not found, create it (upsert behavior)
        await docRef.set(updatedEvent.toFirestore());
      }
    } catch (e) {
      debugPrint('Error updating event: $e');
      rethrow;
    }
  }

  /// Deletes an event from Firestore for the current user.
  Future<void> deleteEvent(String eventId) async {
    if (_userId == null) {
      debugPrint("deleteEvent: User ID is null, cannot delete event.");
      return;
    }
    try {
      final docRef = _getEventsCollectionRef().doc(eventId);
      // Check if the document exists before attempting to delete
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.delete();
        debugPrint('Event deleted: $eventId');
      } else {
        debugPrint('Error deleting event: Document with ID $eventId not found.');
      }
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }

  // --- Badge & User Profile Operations ---

  /// Saves user profile data (like avatar color/icon, email, display name) to Firestore.
  Future<void> saveUserProfileData({
    int? avatarColorValue,
    int? avatarIconCodePoint,
    String? email,
    String? displayName, // New: Optional display name to save
  }) async {
    if (_userId == null) {
      debugPrint("saveUserProfileData: User ID is null, cannot save profile data.");
      return;
    }
    try {
      final dataToSave = <String, dynamic>{};
      if (avatarColorValue != null) {
        dataToSave['avatarColorValue'] = avatarColorValue;
      }
      if (avatarIconCodePoint != null) {
        dataToSave['avatarIconCodePoint'] = avatarIconCodePoint;
      }
      if (email != null) {
        dataToSave['email'] = email;
      }
      if (displayName != null) { // Add display name to data to save
        dataToSave['displayName'] = displayName;
      }

      if (dataToSave.isNotEmpty) {
        await _getUserDataDocRef().set(dataToSave, SetOptions(merge: true));
        debugPrint('User profile data saved: $dataToSave');
      }
    } catch (e) {
      debugPrint('Error saving user profile data: $e');
      rethrow;
    }
  }

  /// Retrieves a real-time stream of unlocked badge IDs for the current user.
  Stream<Set<String>> getUnlockedBadgesStream() {
    if (_userId == null) {
      debugPrint("getUnlockedBadgesStream: User ID is null, returning empty stream.");
      return Stream.value({}); // Return empty set if not authenticated yet
    }
    return _getUserDataDocRef().snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data.containsKey('unlockedBadgeIds') && data['unlockedBadgeIds'] is List) {
          return Set<String>.from(data['unlockedBadgeIds']);
        }
      }
      return {}; // Return empty set if no data or invalid data
    });
  }

  /// Retrieves a real-time stream of user profile data.
  Stream<Map<String, dynamic>> getUserProfileStream() {
    if (_userId == null) {
      debugPrint("getUserProfileStream: User ID is null, returning empty stream.");
      return Stream.value({});
    }
    return _getUserDataDocRef().snapshots().map((snapshot) {
      return snapshot.data() ?? {};
    });
  }

  // --- Mood Entry Operations ---

  /// Adds or updates a mood entry for a specific date.
  Future<void> addOrUpdateMoodEntry(MoodEntry moodEntry) async {
    if (_userId == null) {
      debugPrint("addOrUpdateMoodEntry: User ID is null, cannot save mood entry.");
      return;
    }
    try {
      // Use the date (formatted as YYYY-MM-DD) as the document ID for easy lookup
      await _getMoodEntriesCollectionRef().doc(moodEntry.id).set(moodEntry.toFirestore());
      debugPrint('Mood entry saved for ${moodEntry.date}: ${moodEntry.moodRating}');
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of mood entries for the current user, ordered by date.
  Stream<List<MoodEntry>> getMoodEntries() {
    if (_userId == null) {
      debugPrint("getMoodEntries: User ID is null, returning empty stream.");
      return Stream.value([]);
    }
    return _getMoodEntriesCollectionRef().orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
    });
  }

  /// Deletes a mood entry.
  Future<void> deleteMoodEntry(String moodEntryId) async {
    if (_userId == null) {
      debugPrint("deleteMoodEntry: User ID is null, cannot delete mood entry.");
      return;
    }
    try {
      await _getMoodEntriesCollectionRef().doc(moodEntryId).delete();
      debugPrint('Mood entry deleted: $moodEntryId');
    } catch (e) {
      debugPrint('Error deleting mood entry: $e');
      rethrow;
    }
  }

  // --- Personal Note Operations ---

  /// Adds a new personal note.
  Future<void> addPersonalNote(PersonalNote note) async {
    if (_userId == null) {
      debugPrint("addPersonalNote: User ID is null, cannot add personal note.");
      return;
    }
    try {
      await _getPersonalNotesCollectionRef().add(note.toFirestore()); // Use .add() for auto-ID
      debugPrint('Personal note added: ${note.content}');
    } catch (e) {
      debugPrint('Error adding personal note: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of personal notes for the current user, ordered by timestamp.
  Stream<List<PersonalNote>> getPersonalNotes() {
    if (_userId == null) {
      debugPrint("getPersonalNotes: User ID is null, returning empty stream.");
      return Stream.value([]);
    }
    return _getPersonalNotesCollectionRef().orderBy('timestamp', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PersonalNote.fromFirestore(doc)).toList();
    });
  }

  /// Updates an existing personal note.
  Future<void> updatePersonalNote(PersonalNote note) async {
    if (_userId == null) {
      debugPrint("updatePersonalNote: User ID is null, cannot update personal note.");
      return;
    }
    try {
      await _getPersonalNotesCollectionRef().doc(note.id).update(note.toFirestore());
      debugPrint('Personal note updated: ${note.content}');
    } catch (e) {
      debugPrint('Error updating personal note: $e');
      rethrow;
    }
  }

  /// Deletes a personal note.
  Future<void> deletePersonalNote(String noteId) async {
    if (_userId == null) {
      debugPrint("deletePersonalNote: User ID is null, cannot delete personal note.");
      return;
    }
    try {
      await _getPersonalNotesCollectionRef().doc(noteId).delete();
      debugPrint('Personal note deleted: $noteId');
    } catch (e) {
      debugPrint('Error deleting personal note: $e');
      rethrow;
    }
  }

  void saveUnlockedBadges(Set<String> unlockedBadgeIds) {
    if (_userId == null) {
      debugPrint("saveUnlockedBadges: User ID is null, cannot save badges.");
      return;
    }
    try {
      _getUserDataDocRef().set({'unlockedBadgeIds': unlockedBadgeIds.toList()}, SetOptions(merge: true));
      debugPrint('Unlocked badges saved: $unlockedBadgeIds');
    } catch (e) {
      debugPrint('Error saving unlocked badges: $e');
    }
  }

  // NEW: Method to delete all data associated with the current user.
  Future<void> deleteAllUserData() async {
    if (_userId == null) {
      debugPrint("deleteAllUserData: User ID is null. Cannot delete data.");
      return;
    }

    final batch = _firestore.batch();

    // Helper to delete all documents in a collection
    Future<void> deleteCollection(CollectionReference collRef) async {
      final snapshot = await collRef.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    // Delete all user-specific collections
    await deleteCollection(_getTasksCollectionRef());
    await deleteCollection(_getCategoriesCollectionRef());
    await deleteCollection(_getEventsCollectionRef());
    await deleteCollection(_getMoodEntriesCollectionRef());
    await deleteCollection(_getPersonalNotesCollectionRef());

    // Delete the user profile document
    batch.delete(_getUserDataDocRef());

    try {
      await batch.commit();
      debugPrint('All user data has been deleted for userId: $_userId');
    } catch (e) {
      debugPrint('Error deleting all user data: $e');
      rethrow;
    }
  }
}