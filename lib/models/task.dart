import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

// Represents a single sub-task within a main task.
class Subtask {
  final String id;
  final String title;
  final bool isCompleted;

  Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  // Creates a copy of the subtask with optional new values.
  Subtask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // Creates a Subtask instance from a map (e.g., from Firestore or JSON).
  factory Subtask.fromJson(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  // Converts the Subtask instance to a map for Firestore or JSON storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}

// Represents a main task.
class Task {
  final String id;
  final String title;
  final String? notes;
  final String category;
  final int colorValue; // New: Color for the task, stored as an integer
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final bool isCompleted;
  final bool isImportant;
  final List<Subtask> subtasks;
  final int order;

  Task({
    required this.id,
    required this.title,
    this.notes,
    this.category = 'general',
    this.colorValue = 0xFFF48FB1, // Default color, similar to AppColors.primaryPink
    this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isImportant = false,
    this.subtasks = const [],
    required this.order,
  });

  // Creates a copy of the task with optional new values.
  Task copyWith({
    String? id,
    String? title,
    String? notes,
    String? category,
    int? colorValue, // Added colorValue to copyWith
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? isCompleted,
    bool? isImportant,
    List<Subtask>? subtasks,
    int? order,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue, // Copy colorValue
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isImportant: isImportant ?? this.isImportant,
      subtasks: subtasks ?? this.subtasks,
      order: order ?? this.order,
    );
  }

  // Creates a Task instance from a Firestore document.
  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError("Missing data for Task ${doc.id}");
    }

    // Safely parse TimeOfDay from Firestore map
    TimeOfDay? parseTimeOfDay(Map<String, dynamic>? timeMap) {
      if (timeMap == null) return null;
      return TimeOfDay(hour: timeMap['hour'], minute: timeMap['minute']);
    }

    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      notes: data['notes'],
      category: data['category'] ?? 'general',
      colorValue: data['colorValue'] as int? ?? 0xFFF48FB1, // Retrieve colorValue
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      dueTime: parseTimeOfDay(data['dueTime']),
      isCompleted: data['isCompleted'] ?? false,
      isImportant: data['isImportant'] ?? false,
      subtasks: (data['subtasks'] as List<dynamic>?)
              ?.map((s) => Subtask.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      order: data['order'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Converts the Task instance to a map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'notes': notes,
      'category': category,
      'colorValue': colorValue, // Save colorValue
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'dueTime': dueTime != null ? {'hour': dueTime!.hour, 'minute': dueTime!.minute} : null,
      'isCompleted': isCompleted,
      'isImportant': isImportant,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'order': order,
    };
  }

  // NEW: Creates a Task instance from a JSON map (for import).
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      notes: json['notes'],
      category: json['category'] ?? 'general',
      colorValue: json['colorValue'] as int? ?? 0xFFF48FB1,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      dueTime: json['dueTime'] != null
          ? TimeOfDay(
              hour: int.parse(json['dueTime'].split(':')[0]),
              minute: int.parse(json['dueTime'].split(':')[1]),
            )
          : null,
      isCompleted: json['isCompleted'] ?? false,
      isImportant: json['isImportant'] ?? false,
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((s) => Subtask.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      order: json['order'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // NEW: Converts the Task instance to a JSON map (for export).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'category': category,
      'colorValue': colorValue,
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'isCompleted': isCompleted,
      'isImportant': isImportant,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'order': order,
    };
  }

  // Helper to get Color object from int value
  Color get color => Color(colorValue);
}