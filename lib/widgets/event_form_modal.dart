import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:chrono_dart/chrono_dart.dart';
import '../models/event.dart';
import '../models/category.dart';
import '../services/services.dart';
import '../utils/app_constants.dart';
import '../widgets/category_form_modal.dart';

class EventFormModal extends StatefulWidget {
  final Event? event;
  final bool isNewEvent;
  final Function(Event) onSave;
  final Function(String)? onDelete;
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;
  final FirestoreService firestoreService; // ADDED: FirestoreService dependency
  final DateTime? initialDate;

  const EventFormModal({
    super.key,
    this.event,
    required this.onSave,
    this.onDelete,
    this.isNewEvent = false,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    required this.firestoreService, // ADDED: FirestoreService dependency
    this.initialDate,
  });

  @override
  State<EventFormModal> createState() => _EventFormModalState();
}

class _EventFormModalState extends State<EventFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late bool _isAlarmEnabled;
  late bool _isImportant;
  late String _selectedCategoryName;
  late DateTime _currentCalendarMonth;
  DateTime? _detectedDateTime;
  bool _keepDetectedDateTime = true;
  DateTime? _firstDateInRange;

  String? _recurrenceUnit;
  late int _recurrenceValue;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _startDate = event?.date ?? widget.initialDate;
    _endDate = event?.endDate;
    _startTime = event?.startTime ?? (widget.initialDate != null && event == null ? const TimeOfDay(hour: 9, minute: 0) : null);
    _endTime = event?.endTime;
    _isAlarmEnabled = event?.isAlarmEnabled ?? true;
    _isImportant = event?.isImportant ?? false;
    _selectedCategoryName = event?.category ?? 'general';
    _currentCalendarMonth = _startDate ?? DateTime.now();
    _recurrenceUnit = event?.recurrenceUnit;
    _recurrenceValue = event?.recurrenceValue ?? 1;

    _titleController.addListener(_parseTextForDateTime);
    _descriptionController.addListener(_parseTextForDateTime);
    _parseTextForDateTime();
  }

  @override
  void dispose() {
    _titleController.removeListener(_parseTextForDateTime);
    _descriptionController.removeListener(_parseTextForDateTime);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _parseTextForDateTime() {
    final text = '${_titleController.text} ${_descriptionController.text}'.trim();
    if (text.isEmpty) {
      if (_detectedDateTime != null) setState(() => _detectedDateTime = null);
      return;
    }
    final detectedRaw = Chrono.parseDate(text, ref: DateTime.now());
    DateTime? correctedDateTime;
    if (detectedRaw != null) {
      final offset = DateTime.now().timeZoneOffset;
      correctedDateTime = detectedRaw.add(offset);
    }
    if (correctedDateTime != _detectedDateTime) {
      setState(() {
        _detectedDateTime = correctedDateTime;
        if (correctedDateTime != null) _keepDetectedDateTime = true;
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      if (widget.event != null) {
        notificationService.cancelNotification(NotificationService.createIntIdFromString(widget.event!.id));
      }

      if (widget.isNewEvent) soundService.playAddTaskSound();
      HapticFeedback.mediumImpact();
      final now = DateTime.now();
      final String eventId = widget.event?.id ?? now.millisecondsSinceEpoch.toString();
      final selectedCategory = widget.availableCategories.firstWhere(
        (cat) => cat.name == _selectedCategoryName,
        orElse: () => Category(id: 'general', name: 'general', colorValue: AppColors.primaryPink.value),
      );

      DateTime? finalStartDate;
      DateTime? finalEndDate;
      TimeOfDay? finalStartTime;
      TimeOfDay? finalEndTime;

      if (_keepDetectedDateTime && _detectedDateTime != null) {
        finalStartDate = _detectedDateTime;
        finalStartTime = TimeOfDay.fromDateTime(_detectedDateTime!);
        finalEndDate = null;
        finalEndTime = null;
      } else {
        finalStartDate = _startDate;
        finalEndDate = _endDate;
        finalStartTime = _startTime;
        finalEndTime = _endTime;
      }

      if (finalStartDate != null && finalEndDate != null && finalStartTime != null && finalEndTime != null) {
        DateTime startDateTime = DateTime(finalStartDate.year, finalStartDate.month, finalStartDate.day, finalStartTime.hour, finalStartTime.minute);
        DateTime endDateTime = DateTime(finalEndDate.year, finalEndDate.month, finalEndDate.day, finalEndTime.hour, finalEndTime.minute);
        if (endDateTime.isBefore(startDateTime)) {
          finalEndTime = finalStartTime;
          if (finalEndDate.isBefore(finalStartDate)) finalEndDate = finalStartDate;
        }
      }
      
      final savedEvent = Event(
        id: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        date: finalStartDate ?? now,
        endDate: finalEndDate,
        startTime: finalStartTime,
        endTime: finalEndTime,
        category: _selectedCategoryName,
        colorValue: selectedCategory.colorValue,
        isAlarmEnabled: _isAlarmEnabled,
        isImportant: _isImportant,
        recurrenceUnit: _isAlarmEnabled ? _recurrenceUnit : null,
        recurrenceValue: _isAlarmEnabled ? _recurrenceValue : 1,
      );
      widget.onSave(savedEvent);

      if (_isAlarmEnabled && savedEvent.startTime != null) {
        final scheduledDateTime = DateTime(
          savedEvent.date.year,
          savedEvent.date.month,
          savedEvent.date.day,
          savedEvent.startTime!.hour,
          savedEvent.startTime!.minute,
        );
        
        // *** ADDED: Construct the full end date and time for the event. ***
        DateTime? finalEventEndDate;
        if (savedEvent.endDate != null && savedEvent.endTime != null) {
          finalEventEndDate = DateTime(
            savedEvent.endDate!.year,
            savedEvent.endDate!.month,
            savedEvent.endDate!.day,
            savedEvent.endTime!.hour,
            savedEvent.endTime!.minute,
          );
        }

        notificationService.scheduleReminderNotification(
          id: NotificationService.createIntIdFromString(savedEvent.id),
          title: savedEvent.title,
          body: savedEvent.description ?? 'it\'s happening!',
          scheduledDate: scheduledDateTime,
          context: context,
          type: 'event',
          recurrenceUnit: savedEvent.recurrenceUnit,
          recurrenceValue: savedEvent.recurrenceValue,
          eventEndDate: finalEventEndDate, // *** ADDED: Pass the end date to the notification service. ***
        );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1.0),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildDateTimeSuggestion(),
              const SizedBox(height: 24),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              _buildDateTimeRow(),
              const SizedBox(height: 16),
              _buildAlarmToggle(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (widget.isNewEvent)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        if (!widget.isNewEvent)
          TextButton(
            onPressed: () {
              if (widget.onDelete != null && widget.event != null) {
                // This call is now handled by the FirestoreService deleteEvent method
                // notificationService.cancelNotification(NotificationService.createIntIdFromString(widget.event!.id));
                widget.onDelete!(widget.event!.id);
              }
              Navigator.pop(context);
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _saveEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(widget.isNewEvent ? 'add event' : 'save changes'),
        ),
      ],
    );
  }

  void _showRecurrencePicker() {
    soundService.playModalOpeningSound();
    int tempValue = _recurrenceValue;
    String tempUnit = _recurrenceUnit ?? 'day';
    // *** MODIFIED: Add 'week' to the list of recurrence units. ***
    final units = ['minute', 'hour', 'day', 'week', 'month', 'year'];

    final FixedExtentScrollController valueController = FixedExtentScrollController(initialItem: tempValue - 1);
    final FixedExtentScrollController unitController = FixedExtentScrollController(initialItem: units.indexOf(tempUnit));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
            side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Text('recurrence', style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Quicksand')),
          content: SizedBox(
            height: 200,
            width: double.maxFinite,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Center(child: Text('every', style: theme.textTheme.bodyLarge)),
                ),
                Expanded(
                  flex: 1,
                  child: CupertinoPicker(
                    scrollController: valueController,
                    itemExtent: 40.0,
                    onSelectedItemChanged: (index) {
                      tempValue = index + 1;
                    },
                    looping: true,
                    children: List<Widget>.generate(60, (index) {
                      return Center(child: Text((index + 1).toString(), style: theme.textTheme.bodyLarge));
                    }),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker.builder(
                    scrollController: unitController,
                    itemExtent: 40.0,
                    onSelectedItemChanged: (index) {
                      tempUnit = units[index % units.length];
                    },
                    itemBuilder: (context, index) {
                      return Center(child: Text(units[index % units.length], style: theme.textTheme.bodyLarge));
                    },
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  child: Text('cancel', style: theme.textTheme.labelLarge),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('no repeat', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
                  onPressed: () {
                    setState(() {
                      _recurrenceUnit = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('save', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primaryPink)),
                  onPressed: () {
                    setState(() {
                      _recurrenceValue = tempValue;
                      _recurrenceUnit = tempUnit;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // MODIFIED: This is where the logic you provided is added.
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.isNewEvent ? 'new event' : 'edit event', style: Theme.of(context).textTheme.headlineMedium),
        IconButton(
          icon: Icon(_isImportant ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.accentYellow, size: 30),
          onPressed: () {
            soundService.playMarkAsImportantSound();
            HapticFeedback.mediumImpact();
            setState(() {
              _isImportant = !_isImportant;
            });
            // If it's an existing event, update Firestore immediately.
            // For new events, the state is saved when the user taps 'add event'.
            if (!widget.isNewEvent && widget.event != null) {
              // NOTE: You will need to create a 'toggleEventImportance' method in your
              // FirestoreService, similar to your 'toggleTaskImportance' method.
              widget.firestoreService.toggleEventImportance(widget.event!.id, _isImportant);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _titleController,
      validator: (value) => (value == null || value.trim().isEmpty) ? 'title cannot be empty' : null,
      style: theme.textTheme.titleMedium,
      decoration: InputDecoration(
        labelText: 'event title',
        labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: 'description (optional)',
        labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
        ),
      ),
    );
  }
  
  Widget _buildDateTimeSuggestion() {
    if (_detectedDateTime == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedDate = DateFormat('EEE, MMM d \'at\' h:mm a').format(_detectedDateTime!).toLowerCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryPink.withOpacity(0.2) : AppColors.primaryPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primaryPink.withOpacity(0.5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryPink, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('date suggestion', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryPink, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(formattedDate, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text('keep?', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
              Transform.scale(
                scale: 0.8,
                child: CupertinoSwitch(
                  value: _keepDetectedDateTime,
                  onChanged: (bool value) {
                    HapticFeedback.lightImpact();
                    setState(() => _keepDetectedDateTime = value);
                  },
                  activeColor: AppColors.primaryPink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('category', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.availableCategories.length + 1,
            itemBuilder: (context, index) {
              if (index == widget.availableCategories.length) {
                return _buildAddCategoryChip();
              }
              final category = widget.availableCategories[index];
              final isSelected = _selectedCategoryName == category.name;
              return _buildCategoryChip(category, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddCategoryChip() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: const Icon(Icons.add, color: AppColors.primaryPink, size: 18),
        label: Text('new', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryPink)),
        backgroundColor: theme.colorScheme.surface,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CategoryFormModal(
              existingCategories: widget.availableCategories,
              firestoreService: widget.firestoreService,
              currentCategories: widget.availableCategories,
              onSave: (newCategory) {
                widget.onAddCategory(newCategory);
                setState(() => _selectedCategoryName = newCategory.name);
              },
            ),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Category category, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color getTextColor() {
      if (isSelected) {
        return ThemeData.estimateBrightnessForColor(category.color) == Brightness.dark ? Colors.white : Colors.black;
      }
      return theme.colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onLongPress: () {
          if (category.name != 'general') {
            _showCategoryManagementOptions(category);
          }
        },
        child: ChoiceChip(
          avatar: category.name != 'general'
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          label: Text(category.name),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedCategoryName = category.name);
            }
          },
          selectedColor: category.color,
          backgroundColor: isSelected ? category.color : (isDark ? category.color.withOpacity(0.25) : category.color.withOpacity(0.1)),
          labelStyle: theme.textTheme.labelMedium?.copyWith(color: getTextColor()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? category.color : theme.colorScheme.outline),
          ),
        ),
      ),
    );
  }

  void _showCategoryManagementOptions(Category category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkGrey : AppColors.softCream,
        title: Text('manage "${category.name}"', style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Quicksand')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CategoryFormModal(
                  category: category,
                  existingCategories: widget.availableCategories,
                  firestoreService: widget.firestoreService,
                  currentCategories: widget.availableCategories,
                  onSave: (updatedCategory) {
                    widget.onUpdateCategory(updatedCategory);
                    if (_selectedCategoryName == category.name) {
                      setState(() => _selectedCategoryName = updatedCategory.name);
                    }
                  },
                ),
              );
            },
            child: const Text('edit', style: TextStyle(color: AppColors.primaryPink)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteCategory(category);
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed))),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Category category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.softCream,
        title: Text('delete category?', style: theme.textTheme.titleMedium),
        content: Text('tasks in "${category.name}" will be moved to "general".', style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed))),
          TextButton(
            onPressed: () {
              widget.onDeleteCategory(category.id);
              setState(() => _selectedCategoryName = 'general');
              Navigator.of(context).pop();
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow() {
    final dateFormat = DateFormat('MMM d, yyyy');
    String dateText = 'set date';
    if (_startDate != null) {
      dateText = dateFormat.format(_startDate!).toLowerCase();
      if (_endDate != null &&
          !(_endDate!.year == _startDate!.year &&
              _endDate!.month == _startDate!.month &&
              _endDate!.day == _startDate!.day)) {
        dateText = '${dateFormat.format(_startDate!).toLowerCase()} - ${dateFormat.format(_endDate!).toLowerCase()}';
      }
    }

    String timeText = 'set time';
    if (_startTime != null) {
      timeText = _startTime!.format(context).toLowerCase();
      if (_endTime != null) {
        timeText += ' - ${_endTime!.format(context).toLowerCase()}';
      }
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(dateText, overflow: TextOverflow.ellipsis),
            onPressed: _presentDatePicker,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryPink,
              side: const BorderSide(color: AppColors.primaryPink),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time_rounded, size: 18),
            label: Text(timeText, overflow: TextOverflow.ellipsis),
            onPressed: _presentTimePicker,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryPink,
              side: const BorderSide(color: AppColors.primaryPink),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmToggle() {
    final theme = Theme.of(context);
    final bool isRecurrenceEnabled = _recurrenceUnit != null;
    String recurrenceText = 'no repeat';
    if (isRecurrenceEnabled) {
      recurrenceText = 'repeats every${_recurrenceValue > 1 ? ' $_recurrenceValue' : ''} ${_recurrenceUnit ?? 'day'}${_recurrenceValue > 1 ? 's' : ''}';
    }

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'set alarm',
              style: theme.textTheme.headlineSmall,
            ),
            value: _isAlarmEnabled,
            onChanged: (bool value) {
              setState(() {
                _isAlarmEnabled = value;
                if (!value) {
                  _recurrenceUnit = null;
                }
              });
            },
            activeColor: AppColors.primaryPink,
            inactiveThumbColor: theme.colorScheme.outline,
            secondary: const Icon(Icons.alarm_rounded, color: AppColors.primaryPink),
          ),
          if (_isAlarmEnabled) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, color: isRecurrenceEnabled ? AppColors.primaryPink : theme.colorScheme.onSurface.withOpacity(0.6), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isRecurrenceEnabled) {
                          setState(() {
                            _recurrenceUnit = 'day';
                            _recurrenceValue = 1;
                          });
                        }
                        _showRecurrencePicker();
                      },
                      child: Text(
                        recurrenceText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isRecurrenceEnabled ? AppColors.primaryPink : theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (isRecurrenceEnabled)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      onPressed: () {
                        setState(() => _recurrenceUnit = null);
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _presentDatePicker() {
    setState(() {
      _keepDetectedDateTime = false;
      if (_startDate == null) {
        final now = DateTime.now();
        _startDate = now;
        _endDate = now;
      }
    });

    _firstDateInRange = null;
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final theme = Theme.of(context);
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          child: Text('clear', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        CupertinoButton(
                          child: Text('done', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryPink)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  _buildDatePickerContent(modalSetState),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => setState(() {}));
  }

  void _presentTimePicker() {
    setState(() {
      _keepDetectedDateTime = false;
      if (_startTime == null) {
        _startTime = TimeOfDay.now();
        _endTime = TimeOfDay.now();
      }
    });
    HapticFeedback.lightImpact();

    TimeOfDay initialStartTime = _startTime ?? TimeOfDay.now();
    TimeOfDay initialEndTime = _endTime ?? _startTime ?? TimeOfDay.now();

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text('clear', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                      onPressed: () {
                        setState(() {
                          _startTime = null;
                          _endTime = null;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoButton(
                      child: Text('done', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryPink)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("start time", style: theme.textTheme.labelLarge),
                          ),
                          Expanded(
                            child: _CustomTimePicker(
                              initialTime: initialStartTime,
                              onTimeChanged: (newTime) => setState(() => _startTime = newTime),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("end time", style: theme.textTheme.labelLarge),
                          ),
                          Expanded(
                            child: _CustomTimePicker(
                              initialTime: initialEndTime,
                              onTimeChanged: (newTime) => setState(() => _endTime = newTime),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatePickerContent(StateSetter modalSetState) {
    final theme = Theme.of(context);
    final firstDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, 1);
    final daysInMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.primaryPink),
                onPressed: () => modalSetState(() => _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month - 1, 1)),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentCalendarMonth).toLowerCase(),
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.primaryPink),
                onPressed: () => modalSetState(() => _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 2.5,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              final weekdays = ['s', 'm', 't', 'w', 't', 'f', 's'];
              return Center(
                child: Text(
                  weekdays[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                ),
              );
            },
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final day = index - firstWeekday + 1;
              final currentDay = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, day);
              final isSelected = _isDayInRange(currentDay);
              final isToday = DateUtils.isSameDay(currentDay, DateTime.now());

              return GestureDetector(
                onTap: () => modalSetState(() => _onDaySelected(currentDay)),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryPink : (isToday ? AppColors.secondaryPink.withOpacity(0.5) : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                            width: 1.0,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onDaySelected(DateTime day) {
    if (_firstDateInRange == null) {
      _firstDateInRange = day;
      _startDate = day;
      _endDate = day;
    } else {
      if (day.isBefore(_firstDateInRange!)) {
        _startDate = day;
        _endDate = _firstDateInRange;
      } else {
        _startDate = _firstDateInRange;
        _endDate = day;
      }
      _firstDateInRange = null;
    }
  }

  bool _isDayInRange(DateTime day) {
    if (_firstDateInRange != null) {
      return DateUtils.isSameDay(day, _firstDateInRange);
    }

    if (_startDate == null || _endDate == null) {
      return false;
    }

    final cleanDay = DateUtils.dateOnly(day);
    final cleanStart = DateUtils.dateOnly(_startDate!);
    final cleanEnd = DateUtils.dateOnly(_endDate!);

    return (cleanDay.isAtSameMomentAs(cleanStart) || cleanDay.isAfter(cleanStart)) &&
           (cleanDay.isAtSameMomentAs(cleanEnd) || cleanDay.isBefore(cleanEnd));
  }
}

class _CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const _CustomTimePicker({required this.initialTime, required this.onTimeChanged});

  @override
  _CustomTimePickerState createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<_CustomTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    int initialHour = _selectedTime.hourOfPeriod;
    if (initialHour == 0) initialHour = 12;
    _hourController = FixedExtentScrollController(initialItem: initialHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _selectedTime.minute);
    int initialAmPmIndex = _selectedTime.period == DayPeriod.am ? 0 : 1;
    _amPmController = FixedExtentScrollController(initialItem: 10000 + initialAmPmIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  void _updateSelectedTime() {
    int hour = (_hourController.selectedItem % 12) + 1;
    final int minute = _minuteController.selectedItem % 60;
    final DayPeriod period = (_amPmController.selectedItem % 2) == 0 ? DayPeriod.am : DayPeriod.pm;
    if (period == DayPeriod.pm && hour != 12) {
      hour += 12;
    } else if (period == DayPeriod.am && hour == 12) {
      hour = 0;
    }
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
      widget.onTimeChanged(_selectedTime);
    });
  }

  Widget _buildWheel({required FixedExtentScrollController controller, required int itemCount, required IndexedWidgetBuilder itemBuilder, required ValueChanged<int> onSelectedItemChanged}) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 80.0,
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: AppColors.primaryPink.withOpacity(0.1)),
      looping: true,
      children: List<Widget>.generate(itemCount, (index) => itemBuilder(context, index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _buildWheel(
              controller: _hourController,
              itemCount: 12,
              itemBuilder: (context, index) => Center(child: Text((index + 1).toString(), style: theme.textTheme.bodyLarge)),
              onSelectedItemChanged: (index) => _updateSelectedTime(),
            ),
          ),
          Expanded(
            child: _buildWheel(
              controller: _minuteController,
              itemCount: 60,
              itemBuilder: (context, index) => Center(child: Text(index.toString().padLeft(2, '0'), style: theme.textTheme.bodyLarge)),
              onSelectedItemChanged: (index) => _updateSelectedTime(),
            ),
          ),
          Expanded(
            child: CupertinoPicker.builder(
              scrollController: _amPmController,
              itemExtent: 80.0,
              onSelectedItemChanged: (index) => _updateSelectedTime(),
              itemBuilder: (context, index) {
                final String period = (index % 2 == 0) ? 'am' : 'pm';
                return Center(child: Text(period, style: theme.textTheme.bodyLarge));
              },
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: AppColors.primaryPink.withOpacity(0.1)),
            ),
          ),
        ],
      ),
    );
  }
}