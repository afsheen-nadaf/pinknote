// ignore_for_file: unused_import, depend_on_referenced_packages

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import '../models/event.dart';
import '../models/category.dart';
import '../utils/app_constants.dart';
import '../widgets/day_events_modal.dart';
import '../widgets/event_form_modal.dart';
import '../widgets/category_form_modal.dart';
import '../services/services.dart';

class CalendarScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final List<Event> allEvents;
  final Function(Event) onAddEvent;
  final Function(Event) onUpdateEvent;
  final Function(String) onDeleteEvent;
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;

  const CalendarScreen({
    super.key,
    required this.firestoreService,
    required this.allEvents,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Set<String> _dismissedEventIds = {};
  
  DateTime? _userBirthday;
  StreamSubscription<Map<String, dynamic>>? _userProfileSubscription;


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _listenToUserProfile();
  }
  
  void _listenToUserProfile() {
    _userProfileSubscription = widget.firestoreService.getUserProfileStream().listen((profileData) {
      if (mounted && profileData.containsKey('birthday') && profileData['birthday'] != null) {
        setState(() {
          _userBirthday = (profileData['birthday'] as Timestamp).toDate();
        });
      }
    });
  }

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    super.dispose();
  }

  void _deleteEventWithUndo(Event event) {
    soundService.playSwipeDeleteSound();
    notificationService.cancelNotification(NotificationService.createIntIdFromString(event.id));
    
    setState(() {
      _dismissedEventIds.add(event.id);
    });
    widget.onDeleteEvent(event.id);

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'event "${event.title.toLowerCase()}" deleted.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
        action: SnackBarAction(
          label: 'undo',
          textColor: AppColors.primaryPink,
          onPressed: () {
            _undoDelete(event);
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

  void _undoDelete(Event event) {
    setState(() {
      _dismissedEventIds.remove(event.id);
    });
    widget.onAddEvent(event);
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateUtils.dateOnly(day);

    return widget.allEvents.where((event) {
      if (_dismissedEventIds.contains(event.id)) return false;

      final eventStartDate = DateUtils.dateOnly(event.date);

      if (event.recurrenceUnit == null || event.recurrenceUnit!.isEmpty) {
        final eventEndDate = event.endDate != null ? DateUtils.dateOnly(event.endDate!) : eventStartDate;
        return !normalizedDay.isBefore(eventStartDate) && !normalizedDay.isAfter(eventEndDate);
      }

      if (normalizedDay.isBefore(eventStartDate)) {
        return false;
      }

      if (event.endDate != null) {
        final eventEndDate = DateUtils.dateOnly(event.endDate!);
        if (normalizedDay.isAfter(eventEndDate)) {
          return false;
        }
      }
      
      final recurrenceValue = event.recurrenceValue ?? 1;
      if (recurrenceValue <= 0) return false;

      switch (event.recurrenceUnit) {
        case 'day':
          final diffInDays = normalizedDay.difference(eventStartDate).inDays;
          return diffInDays % recurrenceValue == 0;
        case 'month':
          if (day.day != event.date.day) return false;
          final diffInMonths = (day.year * 12 + day.month) - (event.date.year * 12 + event.date.month);
          return diffInMonths >= 0 && diffInMonths % recurrenceValue == 0;
        case 'year':
          if (day.day != event.date.day || day.month != event.date.month) return false;
          final diffInYears = day.year - event.date.year;
          return diffInYears >= 0 && diffInYears % recurrenceValue == 0;
        case 'minute':
        case 'hour':
          return DateUtils.isSameDay(normalizedDay, eventStartDate);
        default:
          return false;
      }
    }).toList();
  }


  List<Event> _getUpcomingEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Event> upcoming = widget.allEvents.where((event) {
      if (_dismissedEventIds.contains(event.id)) return false;
      if (event.recurrenceUnit != null) {
        if (event.endDate != null) {
          final normalizedEndDate = DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day);
          return !normalizedEndDate.isBefore(today);
        }
        return true;
      }
      final normalizedStartDate = DateTime(event.date.year, event.date.month, event.date.day);
      final normalizedEndDate = event.endDate != null ? DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day) : normalizedStartDate;
      return !normalizedEndDate.isBefore(today);
    }).toList();

    upcoming.sort((a, b) {
      int dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;
      if (a.startTime != null && b.startTime != null) {
        return (a.startTime!.hour * 60 + a.startTime!.minute)
            .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
      }
      return a.startTime != null ? -1 : (b.startTime != null ? 1 : 0);
    });
    return upcoming;
  }
  
  List<Event> _getPastEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Event> past = widget.allEvents.where((event) {
       if (_dismissedEventIds.contains(event.id)) return false;
       if (event.recurrenceUnit != null) {
         if (event.endDate != null) {
            final eventEndDate = event.endDate!;
            final normalizedEventEndDate = DateTime(eventEndDate.year, eventEndDate.month, eventEndDate.day);
            return normalizedEventEndDate.isBefore(today);
         }
         return false;
       }
      final eventEndDate = event.endDate ?? event.date;
      final normalizedEventEndDate = DateTime(eventEndDate.year, eventEndDate.month, eventEndDate.day);
      return normalizedEventEndDate.isBefore(today);
    }).toList();
    past.sort((a, b) => b.date.compareTo(a.date));
    return past;
  }

  void _showDayEventsModal(DateTime day) {
    soundService.playModalOpeningSound();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayEventsModal(
        selectedDate: day,
        eventsForSelectedDate: _getEventsForDay(day),
        onAddEvent: widget.onAddEvent,
        onUpdateEvent: widget.onUpdateEvent,
        onDeleteEvent: (String eventId) {
          final eventToDelete = widget.allEvents.firstWhere((e) => e.id == eventId, orElse: () => widget.allEvents.first);
          _deleteEventWithUndo(eventToDelete);
        },
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
        firestoreService: widget.firestoreService,
      ),
    );
  }

  void _showEventFormModal({Event? event}) {
    soundService.playModalOpeningSound();
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventFormModal(
        event: event,
        isNewEvent: event == null,
        onSave: (savedEvent) {
          if (event == null) {
            widget.onAddEvent(savedEvent);
          } else {
            widget.onUpdateEvent(savedEvent);
          }
        },
        onDelete: (String eventId) {
          final eventToDelete = widget.allEvents.firstWhere((e) => e.id == eventId, orElse: () => widget.allEvents.first);
          _deleteEventWithUndo(eventToDelete);
        },
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
        firestoreService: widget.firestoreService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingEvents = _getUpcomingEvents();
    final pastEvents = _getPastEvents();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCalendarCard(),
            const SizedBox(height: 10),
            _buildUpcomingEventsSection(upcomingEvents),
            if (pastEvents.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPastEventsSection(pastEvents),
            ]
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventFormModal(event: null),
        backgroundColor: AppColors.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 10.0,
        label: Text(
          'add event',
          style: theme.textTheme.labelLarge?.copyWith(color: isDarkMode ? Colors.black : Colors.white),
        ),
        icon: Icon(Icons.event_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCalendarCard() {
    final theme = Theme.of(context);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7;
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
                        DateFormat('MMMM').format(_focusedDay).toLowerCase(),
                        style: GoogleFonts.quicksand(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPink,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy').format(_focusedDay),
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
                        onPressed: () => setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                          _selectedDay = _focusedDay;
                        }),
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                        onPressed: () => setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                          _selectedDay = _focusedDay;
                        }),
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
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
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
                if (index < firstWeekday) return Container();
                
                final day = index - firstWeekday + 1;
                final currentDay = DateTime(_focusedDay.year, _focusedDay.month, day);
                final eventsOnThisDay = _getEventsForDay(currentDay);
                final bool isSelected = _selectedDay != null && DateUtils.isSameDay(_selectedDay, currentDay);
                final bool isToday = DateUtils.isSameDay(currentDay, DateTime.now());
                final todayDateOnly = DateUtils.dateOnly(DateTime.now());
                
                final bool isBirthday = _userBirthday != null &&
                                        currentDay.month == _userBirthday!.month &&
                                        currentDay.day == _userBirthday!.day;

                Color dayColor = Colors.transparent;
                BoxBorder? border;
                List<Widget> markers = [];
                
                final Event? rangeEvent = widget.allEvents.firstWhereOrNull((event) {
                  if (event.endDate == null || DateUtils.isSameDay(event.date, event.endDate!)) return false;

                  final startDate = DateUtils.dateOnly(event.date);
                  final endDate = DateUtils.dateOnly(event.endDate!);

                  if (endDate.isBefore(todayDateOnly)) return false;

                  final cleanCurrentDay = DateUtils.dateOnly(currentDay);
                  return (cleanCurrentDay.isAtSameMomentAs(startDate) || cleanCurrentDay.isAfter(startDate)) &&
                         (cleanCurrentDay.isAtSameMomentAs(endDate) || cleanCurrentDay.isBefore(endDate));
                });

                if (rangeEvent != null) {
                  final rangeColor = rangeEvent.color;
                  dayColor = rangeColor.withOpacity(0.2);
                  final isStart = DateUtils.isSameDay(currentDay, rangeEvent.date);
                  final isEnd = DateUtils.isSameDay(currentDay, rangeEvent.endDate!);
                  if (isStart || isEnd) {
                    border = Border.all(color: rangeColor, width: 2.0);
                  }
                }

                if (isSelected) {
                  dayColor = AppColors.primaryPink.withOpacity(0.8);
                } else if (isToday && rangeEvent == null) {
                  dayColor = AppColors.secondaryPink.withOpacity(0.6);
                }

                final activeEventsOnThisDay = eventsOnThisDay.where((event) {
                  final eventEndDate = event.endDate != null ? DateUtils.dateOnly(event.endDate!) : DateUtils.dateOnly(event.date);
                  return !eventEndDate.isBefore(todayDateOnly);
                }).toList();

                if (activeEventsOnThisDay.isNotEmpty) {
                  final hasImportant = activeEventsOnThisDay.any((e) => e.isImportant);
                  final hasRecurrence = activeEventsOnThisDay.any((e) => e.recurrenceUnit != null && e.recurrenceUnit!.isNotEmpty);

                  if (hasImportant) {
                    markers.add(const Icon(Icons.star_rounded, size: 10, color: AppColors.accentYellow));
                  }
                  if (hasRecurrence) {
                    markers.add(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.0),
                      child: Icon(Icons.repeat_rounded, size: 10, color: isSelected ? Colors.white : AppColors.primaryPink),
                    ));
                  }
                  if (!hasImportant) {
                    markers.add(Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.0),
                      child: Icon(Icons.circle, size: 6, color: (isSelected || rangeEvent != null) ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7)),
                    ));
                  }
                }

                if (border == null) {
                  if (rangeEvent == null && activeEventsOnThisDay.isNotEmpty) {
                    border = Border.all(color: activeEventsOnThisDay.first.color, width: 1.5);
                  } else {
                    border = Border.all(color: AppColors.borderLight.withOpacity(0.5), width: 1);
                  }
                }
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = currentDay);
                    _showDayEventsModal(currentDay);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: dayColor,
                      borderRadius: BorderRadius.circular(8),
                      border: border,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // MODIFIED: Conditionally display birthday icon or date number
                        if (isBirthday)
                          Icon(
                            Icons.cake_outlined, // Use outlined icon
                            size: 28, // Larger icon
                            color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.primaryPink,
                            
                          )
                        else
                          // Original content (day number and event markers)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (markers.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: markers.take(3).toList(),
                                  ),
                                ),
                            ],
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

  Widget _buildUpcomingEventsSection(List<Event> upcomingEvents) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: AppColors.borderLight.withOpacity(0.5), width: 1),
      ),
      elevation: 8.0,
      shadowColor: AppColors.shadowSoft.withOpacity(0.3),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_rounded, color: AppColors.primaryPink),
                const SizedBox(width: 8),
                Text(
                  'upcoming events',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (upcomingEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'no upcoming events. add one!',
                  style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: theme.hintColor),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcomingEvents.length,
                itemBuilder: (context, index) {
                  final event = upcomingEvents[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.0),
                      child: Dismissible(
                        key: ObjectKey(event),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _deleteEventWithUndo(event);
                        },
                        background: Container(
                          decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                        ),
                        child: _buildEventItem(event),
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
  
  Widget _buildPastEventsSection(List<Event> pastEvents) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 2.0,
      shadowColor: AppColors.shadowSoft.withOpacity(0.2),
      color: theme.cardColor,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primaryPink),
              const SizedBox(width: 8),
              Text(
                'past events',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          iconColor: AppColors.primaryPink,
          collapsedIconColor: AppColors.primaryPink,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pastEvents.length,
                itemBuilder: (context, index) {
                  final event = pastEvents[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.0),
                      child: Dismissible(
                        key: ObjectKey(event),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => _deleteEventWithUndo(event),
                        background: Container(
                          decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                        ),
                        child: Opacity(
                          opacity: 0.7,
                          child: _buildEventItem(event)
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(Event event) {
    final theme = Theme.of(context);
    final eventColor = event.color;

    String dateText;
    if (event.recurrenceUnit != null) {
      dateText = 'repeats every ${event.recurrenceValue == 1 ? '' : '${event.recurrenceValue} '}${event.recurrenceUnit!}${event.recurrenceValue == 1 ? '' : 's'}'.trim();
    } else if (event.endDate != null && !DateUtils.isSameDay(event.date, event.endDate)) {
      dateText = '${DateFormat('MMM d, yyyy').format(event.date).toLowerCase()} - ${DateFormat('MMM d, yyyy').format(event.endDate!).toLowerCase()}';
    } else {
      dateText = DateFormat('MMM d, yyyy').format(event.date).toLowerCase();
    }


    return GestureDetector(
      onTap: () => _showEventFormModal(event: event),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: eventColor.withOpacity(0.5), width: 1),
        ),
        elevation: 4.0,
        shadowColor: eventColor.withOpacity(0.3),
        color: eventColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                  fontStyle: event.recurrenceUnit != null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.title.toLowerCase(),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (event.isImportant)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.star_rounded, color: AppColors.accentYellow, size: 20),
                    ),
                ],
              ),
              if (event.description != null && event.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(event.description!.toLowerCase(), style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (event.recurrenceUnit != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.repeat_rounded, size: 16, color: AppColors.primaryPink.withOpacity(0.8)),
                    ),
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryPink),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${event.startTime?.format(context).toLowerCase() ?? 'no time'} - ${event.endTime?.format(context).toLowerCase() ?? 'no time'}',
                      style: GoogleFonts.poppins(color: AppColors.primaryPink, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}