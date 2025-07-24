// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../utils/app_constants.dart';
import '../models/mood_entry.dart';
import '../services/services.dart';

class MoodTrackerScreen extends StatefulWidget {
  final FirestoreService firestoreService; // Pass FirestoreService

  const MoodTrackerScreen({super.key, required this.firestoreService});

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen> {
  DateTime _selectedMonth = DateTime.now(); // Currently displayed month
  Map<String, MoodEntry> _moodsByDate = {}; // Stores moods keyed by 'YYYY-MM-DD'
  List<PersonalNote> _personalNotes = []; // List of personal notes
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode(); // FocusNode for the notes text field
  String? _selectedNoteId; // To track which note is being edited
  final Set<String> _dismissedNoteIds = {};

  final List<Map<String, dynamic>> _moodOptions = [
    {'icon': Icons.sentiment_very_satisfied_rounded, 'rating': 5, 'color': AppColors.accentGreen},
    {'icon': Icons.sentiment_satisfied_rounded, 'rating': 4, 'color': Colors.lightGreen},
    {'icon': Icons.sentiment_neutral_rounded, 'rating': 3, 'color': AppColors.accentYellow},
    {'icon': Icons.sentiment_dissatisfied_rounded, 'rating': 2, 'color': AppColors.accentCoral},
    {'icon': Icons.sentiment_very_dissatisfied_rounded, 'rating': 1, 'color': AppColors.errorRed},
  ];

  @override
  void initState() {
    super.initState();
    _listenToMoodEntries();
    _listenToPersonalNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose(); // Dispose the FocusNode
    super.dispose();
  }

  void _listenToMoodEntries() {
    widget.firestoreService.getMoodEntries().listen((moodEntries) {
      if (mounted) {
        setState(() {
          _moodsByDate = {
            for (var entry in moodEntries)
              DateFormat('yyyy-MM-dd').format(entry.date): entry
          };
        });
      }
    });
  }

  void _listenToPersonalNotes() {
    widget.firestoreService.getPersonalNotes().listen((notes) {
      if (mounted) {
        setState(() {
          _personalNotes = notes;
        });
      }
    });
  }

  void _onMoodSelected(DateTime date, int moodRating) async {
    final String id = DateFormat('yyyy-MM-dd').format(date);
    final existingEntry = _moodsByDate[id];

    if (existingEntry != null) {
      final updatedEntry = existingEntry.copyWith(moodRating: moodRating);
      await widget.firestoreService.addOrUpdateMoodEntry(updatedEntry);
    } else {
      final newEntry = MoodEntry(id: id, date: date, moodRating: moodRating);
      await widget.firestoreService.addOrUpdateMoodEntry(newEntry);
    }
  }

  void _savePersonalNote() async {
    if (_noteController.text.trim().isEmpty) {
      if (_selectedNoteId != null) {
        setState(() {
          _selectedNoteId = null;
        });
      }
      _noteController.clear();
      return;
    }

    final String content = _noteController.text.trim();
    final DateTime now = DateTime.now();

    if (_selectedNoteId != null) {
      final updatedNote = PersonalNote(id: _selectedNoteId!, content: content, timestamp: now);
      await widget.firestoreService.updatePersonalNote(updatedNote);
      setState(() {
        _selectedNoteId = null;
      });
    } else {
      final newNote = PersonalNote(id: now.millisecondsSinceEpoch.toString(), content: content, timestamp: now);
      await widget.firestoreService.addPersonalNote(newNote);
    }
    _noteController.clear();
    _noteFocusNode.unfocus(); // Unfocus after saving
  }

  void _deletePersonalNoteWithUndo(PersonalNote note) {
    soundService.playSwipeDeleteSound();

    setState(() {
      _dismissedNoteIds.add(note.id);
    });

    widget.firestoreService.deletePersonalNote(note.id);

    final theme = Theme.of(context);
    final snackbarContent = note.content.length > 30
        ? '${note.content.substring(0, 30)}...'
        : note.content;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'note deleted: "$snackbarContent"',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
        action: SnackBarAction(
          label: 'undo',
          textColor: AppColors.primaryPink,
          onPressed: () {
            _undoDeleteNote(note);
          },
        ),
        backgroundColor: theme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: AppColors.primaryPink.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        elevation: 6.0,
      ));
  }

  void _undoDeleteNote(PersonalNote note) {
    setState(() {
      _dismissedNoteIds.remove(note.id);
    });
    // This will re-add the note to firestore. The stream listener will update the UI.
    widget.firestoreService.addPersonalNote(note);
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          // Unfocus the text field when tapping outside
          if (_noteFocusNode.hasFocus) {
            _noteFocusNode.unfocus();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildMoodCalendar(),
              const SizedBox(height: 10),
              _buildPersonalNotesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodCalendar() {
    final theme = Theme.of(context);
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = (firstDayOfMonth.weekday == 7) ? 0 : firstDayOfMonth.weekday;
    final screenWidth = MediaQuery.of(context).size.width;
    const calendarHorizontalPadding = 16.0 * 2;
    const gridSpacing = 4.0 * 2 * 7;
    final itemWidth = (screenWidth - calendarHorizontalPadding - gridSpacing) / 7;
    final calculatedChildAspectRatio = itemWidth > 0 ? itemWidth / (itemWidth + 10) : 1.0;

    return Card(
      elevation: 4.0,
      shadowColor: AppColors.shadowSoft.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: AppColors.borderLight.withOpacity(0.5), width: 1),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM').format(_selectedMonth).toLowerCase(),
                        style: GoogleFonts.quicksand(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPink,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy').format(_selectedMonth),
                        style: GoogleFonts.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: _goToPreviousMonth,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                        onPressed: _goToNextMonth,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: calculatedChildAspectRatio,
              ),
              itemCount: 7,
              itemBuilder: (context, index) {
                final weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
                return Center(
                  child: Text(
                    weekdays[index],
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                  ),
                );
              },
            ),
            const Divider(color: AppColors.borderLight),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: calculatedChildAspectRatio,
              ),
              itemCount: daysInMonth + firstWeekday,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                final day = index - firstWeekday + 1;
                final currentDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
                final moodEntry = _moodsByDate[formattedDate];
                final moodData = moodEntry != null
                    ? _moodOptions.firstWhere((opt) => opt['rating'] == moodEntry.moodRating)
                    : null;

                return GestureDetector(
                  onTap: () => _showMoodPicker(currentDate, moodEntry),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: moodData != null ? moodData['color'].withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentDate.day == DateTime.now().day && currentDate.month == DateTime.now().month && currentDate.year == DateTime.now().year
                            ? AppColors.primaryPink
                            : AppColors.borderLight.withOpacity(0.5), // Calendar date border opacity
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (moodData != null)
                          Icon(
                            moodData['icon'] as IconData,
                            size: 18,
                            color: moodData['color'],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker(DateTime date, MoodEntry? existingEntry) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'how was your ${DateFormat('MMM d, yyyy').format(date).toLowerCase()}?',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: _moodOptions.map((mood) {
                  return GestureDetector(
                    onTap: () {
                      _onMoodSelected(date, mood['rating']);
                      Navigator.of(context).pop();
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: mood['color'].withOpacity(0.2),
                      child: Icon(
                        mood['icon'] as IconData,
                        size: 20,
                        color: mood['color'],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (existingEntry != null) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    await widget.firestoreService.deleteMoodEntry(existingEntry.id);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'delete mood',
                    style: GoogleFonts.poppins(color: AppColors.errorRed),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalNotesSection() {
    final theme = Theme.of(context);
    final borderColor = AppColors.borderLight.withOpacity(0.5); 
    final displayedNotes = _personalNotes.where((note) => !_dismissedNoteIds.contains(note.id)).toList();

    return Card(
      elevation: 4.0,
      shadowColor: AppColors.shadowSoft.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: AppColors.borderLight.withOpacity(0.5), width: 1),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2, color: AppColors.primaryPink),
                const SizedBox(width: 8),
                Text(
                  'personal notes',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                TextField(
                  controller: _noteController,
                  focusNode: _noteFocusNode,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'write a new note...',
                    hintStyle: GoogleFonts.poppins(color: theme.hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_selectedNoteId != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() {
                            _noteController.clear();
                            _selectedNoteId = null;
                            _noteFocusNode.unfocus();
                          });
                        },
                        color: theme.hintColor,
                      ),
                    IconButton(
                      icon: Icon(
                        _selectedNoteId == null ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
                        color: AppColors.primaryPink,
                      ),
                      onPressed: _savePersonalNote,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (displayedNotes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'no notes yet. add one above!',
                  style: GoogleFonts.poppins(color: theme.hintColor),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedNotes.length,
                itemBuilder: (context, index) {
                  final note = displayedNotes[index];
                  final displayContent = note.content.length > 100
                      ? '${note.content.substring(0, 100)}...'
                      : note.content;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Dismissible(
                        key: ObjectKey(note),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _deletePersonalNoteWithUndo(note);
                        },
                        background: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: AppColors.errorRed,
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                        ),
                        child: Card(
                          color: Colors.transparent,
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: borderColor, width: 1.0),
                          ),
                          shadowColor: AppColors.shadowSoft.withOpacity(0.2),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _noteController.text = note.content;
                                _selectedNoteId = note.id;
                                _noteFocusNode.requestFocus();
                              });
                            },
                            title: Text(
                              displayContent,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              DateFormat('MMM d, yyyy - hh:mm a').format(note.timestamp).toLowerCase(),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}