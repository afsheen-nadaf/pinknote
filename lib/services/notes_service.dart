import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';

class NotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Collection Reference
  CollectionReference<Map<String, dynamic>> _notesCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  // Get Notes Stream
  Stream<List<Note>> getNotes() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    // FIXED: Removed the composite orderBy('isPinned') to prevent "Missing Index" errors.
    // We will handle the sorting of pinned notes in the UI (notes_screen.dart) instead.
    return _notesCollection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
    });
  }

  // Add Note
  Future<void> addNote(Note note) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(note.id).set(note.toFirestore());
  }

  // Update Note
  Future<void> updateNote(Note note) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(note.id).update(note.toFirestore());
  }

  // Delete Note
  Future<void> deleteNote(String noteId) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(noteId).delete();
  }

  // Toggle Archive
  Future<void> toggleArchive(String noteId, bool currentStatus) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(noteId).update({'isArchived': !currentStatus});
  }

  // Toggle Pin
  Future<void> togglePin(String noteId, bool currentStatus) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(noteId).update({'isPinned': !currentStatus});
  }

  // Toggle Favorite
  Future<void> toggleFavorite(String noteId, bool currentStatus) async {
    final uid = _userId;
    if (uid == null) return;
    await _notesCollection(uid).doc(noteId).update({'isFavorite': !currentStatus});
  }
}

final notesService = NotesService();