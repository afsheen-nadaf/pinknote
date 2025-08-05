import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/routine_entry.dart';
import '../services/firestore_service.dart';
import '../utils/app_constants.dart'; // Assuming AppColors are here
import '../theme_mode_notifier.dart'; // To check theme

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
    // Determine if dark mode is active
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final weekDays = List.generate(7, (index) => _startOfWeek.add(Duration(days: index)));

    // Define colors based on the theme
    final dialogBackgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : AppColors.softCream.withOpacity(0.98);
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black;
    final chevronColor = isDarkMode ? Colors.white70 : Colors.black;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dialogBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekNavigator(context, weekDays, chevronColor),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildRoutinesTable(context, weekDays, primaryTextColor),
                ),
              ),
              const SizedBox(height: 16),
              _buildAddRoutineButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekNavigator(BuildContext context, List<DateTime> weekDays, Color chevronColor) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeWeek(-1),
          color: chevronColor,
        ),
        Expanded(
          child: Text(
            '${DateFormat.yMMMd().format(weekDays.first)} - ${DateFormat.yMMMd().format(weekDays.last)}'.toLowerCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primaryPink,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeWeek(1),
          color: chevronColor,
        ),
      ],
    );
  }

  Widget _buildRoutinesTable(BuildContext context, List<DateTime> weekDays, Color primaryTextColor) {
    return StreamBuilder<List<Routine>>(
      stream: widget.firestoreService.getRoutines(),
      builder: (context, routineSnapshot) {
        if (routineSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
        }
        if (routineSnapshot.hasError) {
          return Center(child: Text("error: ${routineSnapshot.error}".toLowerCase(), style: TextStyle(color: primaryTextColor)));
        }
        if (!routineSnapshot.hasData || routineSnapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text("no routines yet. add one!".toLowerCase(), style: TextStyle(color: primaryTextColor))),
          );
        }
        final routines = routineSnapshot.data!;

        return StreamBuilder<List<RoutineEntry>>(
          stream: widget.firestoreService.getRoutineEntriesForWeek(weekDays.first, weekDays.last),
          builder: (context, entrySnapshot) {
            final entries = entrySnapshot.data ?? [];
            return Column(
              children: [
                _buildTableHeader(context, weekDays, primaryTextColor),
                const SizedBox(height: 8),
                ...routines.map((routine) => _buildRoutineRow(context, routine, entries, weekDays, primaryTextColor)).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTableHeader(BuildContext context, List<DateTime> weekDays, Color primaryTextColor) {
    final dayHeaderStyle = TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPink);
    final routineHeaderStyle = TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor.withOpacity(0.8));
    
    return Row(
      children: [
        Expanded(flex: 4, child: Text("routine".toLowerCase(), style: routineHeaderStyle)),
        const Spacer(flex: 2), // Pushes content to the right
        ...weekDays.map((day) => Expanded(
          flex: 1,
          child: Center(child: Text(DateFormat.E(null).format(day).substring(0,1).toLowerCase(), style: dayHeaderStyle)),
        )),
        Expanded(flex: 2, child: SizedBox()), // For streak icon
      ],
    );
  }

  Widget _buildRoutineRow(BuildContext context, Routine routine, List<RoutineEntry> entries, List<DateTime> weekDays, Color primaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 4, // Match header flex
            child: GestureDetector(
              onLongPress: () => _showDeleteRoutineDialog(context, routine),
              child: Row(
                children: [
                  Icon(IconData(routine.iconCodePoint, fontFamily: 'MaterialIcons'), color: AppColors.primaryPink, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      routine.title.toLowerCase(), 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: primaryTextColor, fontSize: 14.0)
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2), // Match header spacer
          ...weekDays.map((day) {
            bool isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
            final entry = entries.firstWhere(
              (e) => e.routineId == routine.id && isSameDay(e.date, day),
              orElse: () => RoutineEntry(id: '', routineId: routine.id, date: day),
            );
            return Expanded(
              flex: 1, // Match header flex
              child: _buildStatusButton(context, entry)
            );
          }),
          Expanded(
            flex: 2, // Match header flex
            child: _buildStreakIndicator(routine, entries, primaryTextColor),
          ),
        ],
      ),
    );
  }

  /// Returns the correct color for a given routine status.
  Color _getColorForStatus(BuildContext context, RoutineStatus status) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case RoutineStatus.completed: return Colors.green.shade400;
      case RoutineStatus.missed: return Colors.red.shade400;
      default:
        return isDarkMode ? Colors.white54 : Colors.black.withOpacity(0.5);
    }
  }

  /// Builds the icon or custom widget for the routine status.
  Widget _buildStatusIconWidget(BuildContext context, RoutineStatus status) {
    final color = _getColorForStatus(context, status);
    
    switch (status) {
      case RoutineStatus.completed:
        return Icon(Icons.check_circle_rounded, color: color, size: 20);
      case RoutineStatus.missed:
        return Icon(Icons.cancel_rounded, color: color, size: 20);
      default: // Pending
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 1.5, // Thinner border
            ),
          ),
        );
    }
  }

  Widget _buildStatusButton(BuildContext context, RoutineEntry entry) {
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
      child: _buildStatusIconWidget(context, entry.status),
    );
  }

  Widget _buildStreakIndicator(Routine routine, List<RoutineEntry> allEntries, Color textColor) {
    final completedEntries = allEntries.where((e) => e.routineId == routine.id && e.status == RoutineStatus.completed).toList();
    if (completedEntries.isEmpty) return const SizedBox.shrink();
    completedEntries.sort((a, b) => b.date.compareTo(a.date));
    final int streak = completedEntries.first.streak;

    if (streak > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department_rounded, color: AppColors.primaryPink.withOpacity(0.8), size: 14),
          const SizedBox(width: 2),
          Text('$streak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textColor)),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAddRoutineButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.add),
        label: Text("add routine".toLowerCase()),
        onPressed: () => _showAddRoutineDialog(context),
      ),
    );
  }

  void _showAddRoutineDialog(BuildContext context) {
    final titleController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBackgroundColor = isDarkMode ? const Color(0xFF2C2C2E) : AppColors.softCream;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black.withOpacity(0.6);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("new routine".toLowerCase(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: "routine name".toLowerCase(),
            labelStyle: TextStyle(color: hintColor),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: hintColor.withOpacity(0.5))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPink)),
          ),
          style: TextStyle(color: textColor),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("cancel", style: TextStyle(color: textColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
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
            child: Text("add".toLowerCase()),
          ),
        ],
      ),
    );
  }

  void _showDeleteRoutineDialog(BuildContext context, Routine routine) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBackgroundColor = isDarkMode ? const Color(0xFF2C2C2E) : AppColors.softCream;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("delete routine?".toLowerCase(), style: TextStyle(color: textColor)),
        content: Text("are you sure you want to delete '${routine.title.toLowerCase()}'? this cannot be undone.".toLowerCase(), style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("cancel", style: TextStyle(color: textColor))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
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