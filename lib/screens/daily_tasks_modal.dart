import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../services/firestore_service.dart';
import '../utils/app_constants.dart'; // Assuming AppColors are here

class DailyRoutinesModal extends StatefulWidget {
  final FirestoreService firestoreService;

  const DailyRoutinesModal({super.key, required this.firestoreService});

  @override
  _DailyRoutinesModalState createState() => _DailyRoutinesModalState();
}

class _DailyRoutinesModalState extends State<DailyRoutinesModal> {
  late DateTime _startOfWeek;

  @override
  void initState() {
    super.initState();
    _startOfWeek = _getStartOfWeek(DateTime.now());
  }

  /// Calculates the start of the week (Monday) for a given date.
  DateTime _getStartOfWeek(DateTime date) {
    // weekday returns 1 for Monday, 7 for Sunday.
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Moves the calendar view forward or backward by one week.
  void _changeWeek(int weeks) {
    setState(() {
      _startOfWeek = _startOfWeek.add(Duration(days: 7 * weeks));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekDays = List.generate(7, (index) => _startOfWeek.add(Duration(days: index)));

    // THEME: Use a cream background color
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.softCream.withOpacity(0.98),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWeekNavigator(theme, weekDays),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildRoutinesTable(theme, weekDays),
                ),
              ),
              const SizedBox(height: 16),
              _buildAddRoutineButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekNavigator(ThemeData theme, List<DateTime> weekDays) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeWeek(-1),
          color: AppColors.primaryPink,
        ),
        Text(
          // THEME: lowercase text
          '${DateFormat.yMMMd().format(weekDays.first)} - ${DateFormat.yMMMd().format(weekDays.last)}'.toLowerCase(),
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.primaryPink, // THEME: pink text
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeWeek(1),
          color: AppColors.primaryPink,
        ),
      ],
    );
  }

  Widget _buildRoutinesTable(ThemeData theme, List<DateTime> weekDays) {
    return StreamBuilder<List<Routine>>(
      stream: widget.firestoreService.getRoutines(),
      builder: (context, routineSnapshot) {
        if (routineSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
        }
        if (routineSnapshot.hasError) {
          return Center(child: Text("error: ${routineSnapshot.error}".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink)));
        }
        if (!routineSnapshot.hasData || routineSnapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text("no routines yet. add one!".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink))),
          );
        }
        final routines = routineSnapshot.data!;

        return StreamBuilder<List<RoutineEntry>>(
          stream: widget.firestoreService.getRoutineEntriesForWeek(weekDays.first, weekDays.last),
          builder: (context, entrySnapshot) {
            final entries = entrySnapshot.data ?? [];
            return Column(
              children: [
                _buildTableHeader(theme, weekDays),
                const SizedBox(height: 8),
                ...routines.map((routine) => _buildRoutineRow(theme, routine, entries, weekDays)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTableHeader(ThemeData theme, List<DateTime> weekDays) {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPink.withOpacity(0.8));
    return Row(
      children: [
        Expanded(flex: 3, child: Text("routine".toLowerCase(), style: headerStyle)),
        ...weekDays.map((day) => Expanded(
          flex: 1,
          child: Center(child: Text(DateFormat.E(null).format(day).substring(0,1).toLowerCase(), style: headerStyle)),
        )),
        const SizedBox(width: 48), // For streak icon
      ],
    );
  }

  Widget _buildRoutineRow(ThemeData theme, Routine routine, List<RoutineEntry> entries, List<DateTime> weekDays) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onLongPress: () => _showDeleteRoutineDialog(routine),
              child: Row(
                children: [
                  Icon(IconData(routine.iconCodePoint, fontFamily: 'MaterialIcons'), color: AppColors.primaryPink),
                  const SizedBox(width: 8),
                  Expanded(child: Text(routine.title.toLowerCase(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primaryPink))),
                ],
              ),
            ),
          ),
          ...weekDays.map((day) {
            bool isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
            final entry = entries.firstWhere(
              (e) => e.routineId == routine.id && isSameDay(e.date, day),
              orElse: () => RoutineEntry(id: '', routineId: routine.id, date: day),
            );
            return Expanded(flex: 1, child: _buildStatusButton(entry));
          }),
          SizedBox(
            width: 48,
            child: _buildStreakIndicator(routine, entries),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(RoutineEntry entry) {
    return GestureDetector(
      onTap: () {
        RoutineStatus newStatus;
        switch (entry.status) {
          case RoutineStatus.pending:
            newStatus = RoutineStatus.completed;
            break;
          case RoutineStatus.completed:
            newStatus = RoutineStatus.missed;
            break;
          case RoutineStatus.missed:
            newStatus = RoutineStatus.pending;
            break;
        }
        widget.firestoreService.updateRoutineEntryStatus(entry.routineId, entry.date, newStatus);
      },
      child: Icon(
        _getIconForStatus(entry.status),
        color: _getColorForStatus(entry.status),
        size: 28,
      ),
    );
  }
  
  IconData _getIconForStatus(RoutineStatus status) {
    switch (status) {
      case RoutineStatus.completed: return Icons.check_circle;
      case RoutineStatus.missed: return Icons.cancel;
      default: return Icons.radio_button_unchecked;
    }
  }

  Color _getColorForStatus(RoutineStatus status) {
    switch (status) {
      case RoutineStatus.completed: return AppColors.primaryPink;
      case RoutineStatus.missed: return AppColors.primaryPink.withOpacity(0.4);
      default: return AppColors.primaryPink.withOpacity(0.2);
    }
  }

  Widget _buildStreakIndicator(Routine routine, List<RoutineEntry> allEntries) {
    final completedEntries = allEntries.where((e) => e.routineId == routine.id && e.status == RoutineStatus.completed).toList();
    if (completedEntries.isEmpty) return const SizedBox.shrink();
    completedEntries.sort((a, b) => b.date.compareTo(a.date));
    final int streak = completedEntries.first.streak;

    if (streak > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department_rounded, color: AppColors.primaryPink.withOpacity(0.8), size: 18),
          const SizedBox(width: 4),
          Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryPink)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAddRoutineButton(ThemeData theme) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPink.withOpacity(0.15),
        foregroundColor: AppColors.primaryPink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: const Icon(Icons.add),
      label: Text("add new routine".toLowerCase()),
      onPressed: () => _showAddRoutineDialog(),
    );
  }

  void _showAddRoutineDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.softCream,
        title: Text("new routine".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink)),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: "routine name".toLowerCase(),
            labelStyle: const TextStyle(color: AppColors.primaryPink),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPink)),
          ),
          style: const TextStyle(color: AppColors.primaryPink),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("cancel".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink))),
          TextButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final newRoutine = Routine(
                  id: const Uuid().v4(),
                  title: titleController.text.trim(),
                  iconCodePoint: Icons.star_border_rounded.codePoint,
                  colorHex: '#${AppColors.primaryPink.value.toRadixString(16).substring(2)}',
                  createdAt: DateTime.now(),
                );
                widget.firestoreService.addRoutine(newRoutine);
                Navigator.pop(context);
              }
            },
            child: Text("add".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink)),
          ),
        ],
      ),
    );
  }

  void _showDeleteRoutineDialog(Routine routine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.softCream,
        title: Text("delete routine?".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink)),
        content: Text("are you sure you want to delete '${routine.title.toLowerCase()}'? this cannot be undone.".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("cancel".toLowerCase(), style: const TextStyle(color: AppColors.primaryPink))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryPink.withOpacity(0.7)),
            onPressed: () {
              widget.firestoreService.deleteRoutine(routine.id);
              Navigator.pop(context);
            },
            child: Text("delete".toLowerCase()),
          ),
        ],
      ),
    );
  }
}