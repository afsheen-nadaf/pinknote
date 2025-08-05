import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Event {
  final String id;
  String title;
  String? description;
  DateTime date; // This will now represent the start date
  DateTime? endDate; // Optional end date for a range
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String category;
  int colorValue;
  final bool isAlarmEnabled;
  final bool isImportant;
  final String? recurrenceUnit;
  final int? recurrenceValue;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    this.category = 'general',
    this.colorValue = 0xFFF48FB1, // Default to primaryPink from AppColors
    this.isAlarmEnabled = true,
    this.isImportant = false,
    this.recurrenceUnit,
    this.recurrenceValue,
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
      category: data['category'] as String? ?? 'general',
      colorValue: data['colorValue'] as int? ?? 0xFFF48FB1,
      isAlarmEnabled: data['isAlarmEnabled'] as bool? ?? true,
      isImportant: data['isImportant'] as bool? ?? false, // FIX: Added isImportant
      recurrenceUnit: data['recurrenceUnit'] as String?,
      recurrenceValue: data['recurrenceValue'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'startTime': startTime != null
          ? {'hour': startTime!.hour, 'minute': startTime!.minute}
          : null,
      'endTime': endTime != null
          ? {'hour': endTime!.hour, 'minute': endTime!.minute}
          : null,
      'category': category,
      'colorValue': colorValue,
      'isAlarmEnabled': isAlarmEnabled,
      'isImportant': isImportant, // FIX: Added isImportant
      'recurrenceUnit': recurrenceUnit,
      'recurrenceValue': recurrenceValue,
    };
  }

  // NEW: Creates an Event instance from a JSON map (for import).
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      description: json['description'],
      date: DateTime.parse(json['date']),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      startTime: json['startTime'] != null
          ? TimeOfDay(
              hour: int.parse(json['startTime'].split(':')[0]),
              minute: int.parse(json['startTime'].split(':')[1]),
            )
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay(
              hour: int.parse(json['endTime'].split(':')[0]),
              minute: int.parse(json['endTime'].split(':')[1]),
            )
          : null,
      category: json['category'] ?? 'general',
      colorValue: json['colorValue'] as int? ?? 0xFFF48FB1,
      isAlarmEnabled: json['isAlarmEnabled'] as bool? ?? true,
      isImportant: json['isImportant'] as bool? ?? false, // FIX: Added isImportant
      recurrenceUnit: json['recurrenceUnit'] as String?,
      recurrenceValue: json['recurrenceValue'] as int?,
    );
  }

  // NEW: Converts the Event instance to a JSON map (for export).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
      'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'category': category,
      'colorValue': colorValue,
      'isAlarmEnabled': isAlarmEnabled,
      'isImportant': isImportant, // FIX: Added isImportant
      'recurrenceUnit': recurrenceUnit,
      'recurrenceValue': recurrenceValue,
    };
  }

  // FIX: Added all missing fields to ensure they are copied correctly.
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
    bool? isAlarmEnabled,
    bool? isImportant,
    String? recurrenceUnit,
    int? recurrenceValue,
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
      isAlarmEnabled: isAlarmEnabled ?? this.isAlarmEnabled,
      isImportant: isImportant ?? this.isImportant,
      recurrenceUnit: recurrenceUnit ?? this.recurrenceUnit,
      recurrenceValue: recurrenceValue ?? this.recurrenceValue,
    );
  }

  // Helper to get Color object from int value
  Color get color => Color(colorValue);
}