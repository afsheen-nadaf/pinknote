import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../models/category.dart';
import '../services/services.dart';
import '../utils/app_constants.dart';
import 'event_form_modal.dart';

class DayEventsModal extends StatefulWidget {
  final DateTime selectedDate;
  final List<Event> eventsForSelectedDate;
  final Function(Event) onAddEvent;
  final Function(Event) onUpdateEvent;
  final Function(String) onDeleteEvent;
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;
  final FirestoreService firestoreService; // ADDED: FirestoreService dependency

  const DayEventsModal({
    super.key,
    required this.selectedDate,
    required this.eventsForSelectedDate,
    required this.onAddEvent,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    required this.firestoreService, // ADDED: FirestoreService dependency
  });

  @override
  State<DayEventsModal> createState() => _DayEventsModalState();
}

class _DayEventsModalState extends State<DayEventsModal> {
  late List<Event> _localEvents;

  @override
  void initState() {
    super.initState();
    _localEvents = List<Event>.from(widget.eventsForSelectedDate);
  }

  void _showEventFormModal({Event? event}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EventFormModal(
          event: event,
          isNewEvent: event == null,
          initialDate: event == null ? widget.selectedDate : null,
          onSave: (savedEvent) {
            if (event == null) {
              widget.onAddEvent(savedEvent);
              setState(() {
                _localEvents.add(savedEvent);
              });
            } else {
              widget.onUpdateEvent(savedEvent);
              setState(() {
                final index = _localEvents.indexWhere((e) => e.id == event.id);
                if (index != -1) {
                  _localEvents[index] = savedEvent;
                }
              });
            }
          },
          onDelete: (eventId) {
            widget.onDeleteEvent(eventId);
            setState(() {
              _localEvents.removeWhere((e) => e.id == eventId);
            });
          },
          availableCategories: widget.availableCategories,
          onAddCategory: widget.onAddCategory,
          onUpdateCategory: widget.onUpdateCategory,
          onDeleteCategory: widget.onDeleteCategory,
          firestoreService: widget.firestoreService, // FIX: Pass the service here
        );
      },
    );
  }

  void _handleDeleteEvent(String eventId, String eventTitle) {
    widget.onDeleteEvent(eventId);
    setState(() {
      _localEvents.removeWhere((e) => e.id == eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedEvents = List<Event>.from(_localEvents)
      ..sort((a, b) {
        if (a.startTime != null && b.startTime != null) {
          return (a.startTime!.hour * 60 + a.startTime!.minute)
              .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
        }
        return a.startTime != null ? -1 : (b.startTime != null ? 1 : 0);
      });

    // Consistent UI with SubtaskFormModal
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'events for ${DateFormat('MMM d, yyyy').format(widget.selectedDate).toLowerCase()}',
                style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primaryPink),
              ),
            ),
            const SizedBox(height: 10),
            if (sortedEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'no events for this day. add one!',
                    style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedEvents.length,
                  itemBuilder: (context, index) {
                    final event = sortedEvents[index];
                    return Dismissible(
                      key: ValueKey(event.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _handleDeleteEvent(event.id, event.title.toLowerCase());
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            borderRadius: BorderRadius.circular(15.0)),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      child: _buildEventTimelineItem(event),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            // Consistent button layout
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  // Changed to TextButton for consistency
                  child: Text('close', style: theme.textTheme.labelLarge),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showEventFormModal(event: null),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('add event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    foregroundColor: Colors.white,
                    // Consistent shape and padding
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTimelineItem(Event event) {
    final theme = Theme.of(context);
    final Color eventColor = event.color;

    return GestureDetector(
      onTap: () => _showEventFormModal(event: event),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  side: BorderSide(color: eventColor.withOpacity(0.5), width: 1),
                ),
                elevation: 4.0,
                shadowColor: eventColor.withOpacity(0.3),
                // Shaded with category color
                color: eventColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.endDate != null && !event.date.isAtSameMomentAs(event.endDate!)
                            ? '${DateFormat('MMM d').format(event.date).toLowerCase()} - ${DateFormat('MMM d, yyyy').format(event.endDate!).toLowerCase()}'
                            : DateFormat('MMM d, yyyy').format(event.date).toLowerCase(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.title.toLowerCase(),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (event.description != null && event.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(event.description!.toLowerCase(),
                              style: theme.textTheme.bodyMedium),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 16, color: AppColors.primaryPink),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${event.startTime?.format(context).toLowerCase() ?? 'no time'} - ${event.endTime?.format(context).toLowerCase() ?? 'no time'}',
                              style: GoogleFonts.poppins(
                                  color: AppColors.primaryPink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}