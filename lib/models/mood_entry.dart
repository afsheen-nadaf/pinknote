import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single mood entry for a specific date.
class MoodEntry {
  final String id; // Unique ID for the mood entry (e.g., date in YYYY-MM-DD format)
  final DateTime date; // The date of the mood entry
  final int moodRating; // A numerical rating for mood (e.g., 1-5)
  final String? note; // Optional personal note for the day

  MoodEntry({
    required this.id,
    required this.date,
    required this.moodRating,
    this.note,
  });

  // Factory constructor to create a MoodEntry from a Firestore document.
  factory MoodEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MoodEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      moodRating: data['moodRating'] as int,
      note: data['note'] as String?,
    );
  }

  // Converts the MoodEntry instance to a map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'moodRating': moodRating,
      'note': note,
    };
  }

  // Creates a copy of the MoodEntry with optional new values.
  MoodEntry copyWith({
    String? id,
    DateTime? date,
    int? moodRating,
    String? note,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      moodRating: moodRating ?? this.moodRating,
      note: note ?? this.note,
    );
  }
}

// Represents a standalone personal note.
class PersonalNote {
  final String id; // Unique ID for the note
  final String content; // The content of the note
  final DateTime timestamp; // Date and time when the note was created/updated

  PersonalNote({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  // Factory constructor to create a PersonalNote from a Firestore document.
  factory PersonalNote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PersonalNote(
      id: doc.id,
      content: data['content'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Converts the PersonalNote instance to a map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Creates a copy of the PersonalNote with optional new values.
  PersonalNote copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
  }) {
    return PersonalNote(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}