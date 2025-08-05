import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: unused_import
import 'package:uuid/uuid.dart';

class Routine {
  final String id;
  final String title;
  final int iconCodePoint;
  final String colorHex;
  final DateTime createdAt;

  Routine({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.colorHex,
    required this.createdAt,
  });

  // Factory constructor to create a Routine from a Firestore document
  factory Routine.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Routine(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      iconCodePoint: data['iconCodePoint'] ?? 0,
      colorHex: data['colorHex'] ?? '#FFFFFF',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Method to convert a Routine instance to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
