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

  void _deletePersonalNote(String noteId) async {
    await widget.firestoreService.deletePersonalNote(noteId);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryPink),
                  onPressed: _goToPreviousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth).toLowerCase(),
                  style: theme.textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryPink),
                  onPressed: _goToNextMonth,
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
    // Changed borderColor to match the opacity of the calendar dates border
    final borderColor = AppColors.borderLight.withOpacity(0.5); 

    return Card(
      elevation: 4.0,
      shadowColor: AppColors.shadowSoft.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'personal notes',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryPink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
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
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: _savePersonalNote,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedNoteId == null ? Icons.add_rounded : Icons.save_rounded,
                        color: AppColors.primaryPink,
                      ),
                    ),
                  ),
                ),
                prefixIcon: _selectedNoteId != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _noteController.clear();
                              _selectedNoteId = null;
                              _noteFocusNode.unfocus();
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: theme.hintColor),
                          ),
                        ),
                      )
                    : null,
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 15),
            if (_personalNotes.isEmpty)
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
                itemCount: _personalNotes.length,
                itemBuilder: (context, index) {
                  final note = _personalNotes[index];
                  final displayContent = note.content.length > 100
                      ? '${note.content.substring(0, 100)}...'
                      : note.content;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Dismissible(
                        key: ValueKey(note.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          soundService.playSwipeDeleteSound();
                          _deletePersonalNote(note.id);
                          final snackbarContent = note.content.length > 30
                              ? '${note.content.substring(0, 30)}...'
                              : note.content;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('note deleted: "$snackbarContent"', style: GoogleFonts.poppins())),
                          );
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