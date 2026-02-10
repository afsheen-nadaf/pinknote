import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isLocked;
  final String? passwordHash;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorValue;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isLocked = false,
    this.passwordHash,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue = 0xFFFFF8E1, // Default Soft Cream
  });

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Note(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      isPinned: data['isPinned'] ?? false,
      isFavorite: data['isFavorite'] ?? false,
      isArchived: data['isArchived'] ?? false,
      isLocked: data['isLocked'] ?? false,
      passwordHash: data['passwordHash'],
      categoryId: data['categoryId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      colorValue: data['colorValue'] ?? 0xFFFFF8E1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'isArchived': isArchived,
      'isLocked': isLocked,
      'passwordHash': passwordHash,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'colorValue': colorValue,
    };
  }

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isLocked,
    String? passwordHash,
    String? categoryId,
    DateTime? updatedAt,
    int? colorValue,
  }) {
    return Note(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Color get color => Color(colorValue);
}