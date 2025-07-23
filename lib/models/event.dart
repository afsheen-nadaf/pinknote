import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Import for Color

class Event {
  final String id;
  String title;
  String? description;
  DateTime date; // This will now represent the start date
  DateTime? endDate; // Optional end date for a range
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String category; // New: Category for the event
  int colorValue; // New: Color for the event, stored as an integer

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    this.category = 'general', // Default category
    this.colorValue = 0xFFF48FB1, // Default to primaryPink from AppColors
  });

  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Event(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String?,
      date: (data['date'] as Timestamp).toDate(),
      endDate: (data['endDate'] is Timestamp) ? (data['endDate'] as Timestamp).toDate() : null,
      startTime: data['startTime'] != null
          ? TimeOfDay(
              hour: (data['startTime'] as Map)['hour'],
              minute: (data['startTime'] as Map)['minute'],
            )
          : null,
      endTime: data['endTime'] != null
          ? TimeOfDay(
              hour: (data['endTime'] as Map)['hour'],
              minute: (data['endTime'] as Map)['minute'],
            )
          : null,
      category: data['category'] as String? ?? 'general', // Retrieve category
      colorValue: data['colorValue'] as int? ?? 0xFFF48FB1, // Retrieve color
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date), // This is the start date
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null, // Save endDate
      'startTime': startTime != null
          ? {'hour': startTime!.hour, 'minute': startTime!.minute}
          : null,
      'endTime': endTime != null
          ? {'hour': endTime!.hour, 'minute': endTime!.minute}
          : null,
      'category': category, // Save category
      'colorValue': colorValue, // Save color
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? category,
    int? colorValue,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  // Helper to get Color object from int value
  Color get color => Color(colorValue);
}