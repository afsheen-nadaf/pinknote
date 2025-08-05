import 'package:cloud_firestore/cloud_firestore.dart';

enum RoutineStatus { pending, completed, missed }

class RoutineEntry {
  final String id; // Combination of routineId and date string
  final String routineId;
  final DateTime date;
  final RoutineStatus status;
  final int streak;

  RoutineEntry({
    required this.id,
    required this.routineId,
    required this.date,
    this.status = RoutineStatus.pending,
    this.streak = 0,
  });

  // Factory constructor to create a RoutineEntry from a Firestore document
  factory RoutineEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RoutineEntry(
      id: doc.id,
      routineId: data['routineId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: _statusFromString(data['status']),
      streak: data['streak'] ?? 0,
    );
  }

  // Helper to convert string from Firestore to enum
  static RoutineStatus _statusFromString(String? status) {
    switch (status) {
      case 'completed':
        return RoutineStatus.completed;
      case 'missed':
        return RoutineStatus.missed;
      default:
        return RoutineStatus.pending;
    }
  }

  // Method to convert a RoutineEntry instance to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'routineId': routineId,
      'date': Timestamp.fromDate(date),
      'status': status.toString().split('.').last, // 'completed', 'missed', or 'pending'
      'streak': streak,
    };
  }
}