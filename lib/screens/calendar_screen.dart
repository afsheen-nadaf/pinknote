// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../models/category.dart';
import '../utils/app_constants.dart';
import '../widgets/day_events_modal.dart';
import '../widgets/event_form_modal.dart';
import '../widgets/category_form_modal.dart'; // Assuming this modal exists for category editing
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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return widget.allEvents.where((event) {
      final normalizedEventStartDate = DateTime(event.date.year, event.date.month, event.date.day);
      final normalizedEventEndDate = event.endDate != null
          ? DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day)
          : normalizedEventStartDate;

      bool isEventPast = normalizedEventEndDate.isBefore(normalizedToday);
      if (isEventPast) return false;

      return (normalizedDay.isAfter(normalizedEventStartDate) || normalizedDay.isAtSameMomentAs(normalizedEventStartDate)) &&
             (normalizedDay.isBefore(normalizedEventEndDate) || normalizedDay.isAtSameMomentAs(normalizedEventEndDate));
    }).toList();
  }

  List<Event> _getUpcomingEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Event> upcoming = widget.allEvents.where((event) {
      final normalizedStartDate = DateTime(event.date.year, event.date.month, event.date.day);
      final normalizedEndDate = event.endDate != null ? DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day) : normalizedStartDate;
      return normalizedEndDate.isAfter(today) || normalizedEndDate.isAtSameMomentAs(today);
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
          notificationService.cancelNotification(eventId.hashCode);
          widget.onDeleteEvent(eventId);
        },
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
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
          notificationService.cancelNotification(eventId.hashCode);
          widget.onDeleteEvent(eventId);
        },
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingEvents = _getUpcomingEvents();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //const SizedBox(height: 20),
            _buildCalendarCard(upcomingEvents),
            const SizedBox(height: 10),
            _buildUpcomingEventsSection(upcomingEvents),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventFormModal(event: null),
        backgroundColor: AppColors.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 10.0,
        label: Text(
          'new event',
          style: theme.textTheme.labelLarge?.copyWith(color: isDarkMode ? Colors.black : Colors.white),
        ),
        icon: Icon(Icons.event_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCalendarCard(List<Event> upcomingEvents) {
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
                  onPressed: () => setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                    _selectedDay = _focusedDay;
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay).toLowerCase(),
                  style: theme.textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryPink),
                  onPressed: () => setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                    _selectedDay = _focusedDay;
                  }),
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

                Color dayColor = Colors.transparent;
                Event? startOrEndEvent;

                for (final event in upcomingEvents) {
                  final isStartDate = DateUtils.isSameDay(event.date, currentDay);
                  final isEndDate = event.endDate != null && DateUtils.isSameDay(event.endDate!, currentDay);
                  if (isStartDate || isEndDate) {
                    startOrEndEvent = event;
                    break;
                  }
                }

                if (isSelected) {
                  dayColor = AppColors.primaryPink.withOpacity(0.8);
                } else if (startOrEndEvent != null) {
                  dayColor = startOrEndEvent.color.withOpacity(0.3);
                } else if (isToday) {
                  dayColor = AppColors.secondaryPink.withOpacity(0.6);
                }

                final Border? border;
                if (eventsOnThisDay.isNotEmpty) {
                  border = Border.all(color: eventsOnThisDay.first.color, width: 1.5);
                } else {
                  border = Border.all(color: AppColors.borderLight.withOpacity(0.5), width: 1);
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (eventsOnThisDay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: dayColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            ),
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
            Text(
              'upcoming events',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryPink,
                letterSpacing: -0.5,
              ),
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
                        key: ValueKey(event.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          soundService.playSwipeDeleteSound();
                          notificationService.cancelNotification(event.id.hashCode);
                          widget.onDeleteEvent(event.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('event "${event.title.toLowerCase()}" deleted.', style: GoogleFonts.poppins())),
                          );
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
                        child: _buildUpcomingEventItem(event),
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

  Widget _buildUpcomingEventItem(Event event) {
    final theme = Theme.of(context);
    final eventColor = event.color;

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
                event.endDate != null && !DateUtils.isSameDay(event.date, event.endDate)
                    ? '${DateFormat('MMM d, yyyy').format(event.date).toLowerCase()} - ${DateFormat('MMM d, yyyy').format(event.endDate!).toLowerCase()}'
                    : DateFormat('MMM d, yyyy').format(event.date).toLowerCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.title.toLowerCase(),
                style: theme.textTheme.titleMedium,
              ),
              if (event.description != null && event.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(event.description!.toLowerCase(), style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
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