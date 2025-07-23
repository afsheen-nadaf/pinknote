import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Import for Color
// Import AppColors

class Category {
  final String id;
  String name;
  int colorValue; // New: Store color as an integer value

  Category({
    required this.id,
    required this.name,
    this.colorValue = 0xFFF48FB1, // Fixed: Directly use the hexadecimal value of AppColors.primaryPink
  });

  factory Category.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Category(
      id: doc.id,
      name: data['name'] as String,
      colorValue: data['colorValue'] as int? ?? 0xFFF48FB1, // Fixed: Directly use the hexadecimal value of AppColors.primaryPink
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorValue': colorValue, // Save color value to Firestore
    };
  }

  Category copyWith({
    String? id,
    String? name,
    int? colorValue,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  // Helper to get Color object from int value
  Color get color => Color(colorValue);
}