// ignore_for_file: unused_element, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For CupertinoPicker
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:intl/intl.dart'; // For DateFormat
import 'package:chrono_dart/chrono_dart.dart'; // Import chrono_dart
import '../models/event.dart';
import '../models/category.dart'; // Import Category model
import '../services/services.dart';
import '../utils/app_constants.dart';
import '../widgets/category_form_modal.dart'; // Import CategoryFormModal

class EventFormModal extends StatefulWidget {
  final Event? event; // Null for new, Event object for editing
  final bool isNewEvent; // Flag to indicate if it's a new event
  final Function(Event) onSave;
  final Function(String)? onDelete;
  final List<Category> availableCategories; // New: Available categories
  final Function(Category) onAddCategory; // New: Function to add category
  final Function(Category) onUpdateCategory; // New: Function to update category
  final Function(String) onDeleteCategory; // New: Function to delete category


  const EventFormModal({
    super.key,
    this.event,
    required this.onSave,
    this.onDelete,
    this.isNewEvent = false, // Default to false if not provided
    required this.availableCategories, // New: Required
    required this.onAddCategory, // New: Required
    required this.onUpdateCategory, // New: Required
    required this.onDeleteCategory, // New: Required
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
  late bool _isAlarmEnabled; // New: State for alarm toggle
  late String _selectedCategoryName; // New: Selected category name for event
  late DateTime _currentCalendarMonth;

  // State for auto-detected date
  DateTime? _detectedDateTime;
  bool _keepDetectedDateTime = true;

  // New state variable to handle date range selection
  DateTime? _firstDateInRange;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _startDate = event?.date;
    _endDate = event?.endDate; // Initialize end date
    _startTime = event?.startTime;
    _endTime = event?.endTime;
    _isAlarmEnabled = widget.event != null; // Default alarm to on if editing an event
    _selectedCategoryName = event?.category ?? 'general'; // Initialize selected category
    _currentCalendarMonth = _startDate ?? DateTime.now();

    // Add listeners to parse text for dates
    _titleController.addListener(_parseTextForDateTime);
    _descriptionController.addListener(_parseTextForDateTime);
    _parseTextForDateTime(); // Initial parse
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
      if (_detectedDateTime != null) {
        setState(() => _detectedDateTime = null);
      }
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
        if (correctedDateTime != null) {
          _keepDetectedDateTime = true; // Auto-select new suggestions
        }
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      if (widget.isNewEvent) {
        soundService.playAddTaskSound();
      }
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
        finalEndDate = null; // Clear end date when using suggestion
        finalEndTime = null; // Clear end time when using suggestion
      } else {
        finalStartDate = _startDate;
        finalEndDate = _endDate;
        finalStartTime = _startTime;
        finalEndTime = _endTime;
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
      );
      widget.onSave(savedEvent);

      // Schedule or cancel notification based on alarm toggle
      if (_isAlarmEnabled && savedEvent.startTime != null) {
        final scheduledDateTime = DateTime(
          savedEvent.date.year,
          savedEvent.date.month,
          savedEvent.date.day,
          savedEvent.startTime!.hour,
          savedEvent.startTime!.minute,
        );
        notificationService.scheduleReminderNotification(
          id: savedEvent.id.hashCode,
          title: 'event: ${savedEvent.title}', // Ensure lowercase
          body: savedEvent.description?.toLowerCase() ?? 'this event is starting now.', // Ensure lowercase
          scheduledDate: scheduledDateTime,
          context: context, // Pass BuildContext here
          type: 'event', // Pass type for payload
        );
      } else {
        notificationService.cancelNotification(savedEvent.id.hashCode);
      }

      Navigator.of(context).pop();
    }
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

    // Reset the range selection process every time the picker is opened.
    _firstDateInRange = null;

    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // FIX: Disable swipe down and tap outside to dismiss
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent, // Important for custom shape
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            // Use a container with clipBehavior to enforce rounded corners on children
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header bar
                  Container(
                    color: isDark ? AppColors.darkGrey : AppColors.softCream,
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
                  // Calendar content
                  Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.only(bottom: 20.0), // Add padding for content
                    child: _buildDatePickerContent(modalSetState),
                  ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    TimeOfDay initialStartTime = _startTime ?? TimeOfDay.now();
    TimeOfDay initialEndTime = _endTime ?? _startTime ?? TimeOfDay.now();

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.softCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkGrey : AppColors.softCream,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
      ),
    );
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
              const SizedBox(height: 24),
              _buildAlarmToggle(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.isNewEvent ? 'new event' : 'edit event', style: Theme.of(context).textTheme.headlineMedium),
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
        title: Text('manage "${category.name}"', style: theme.textTheme.titleMedium),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Widget _buildDatePickerContent(StateSetter modalSetState) {
    final theme = Theme.of(context);
    final firstDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, 1);
    final daysInMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                      width: 1.0,
                    ),
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

  // FIX: Replaced date selection logic
  void _onDaySelected(DateTime day) {
    // This logic now runs inside the modal's `StatefulBuilder`'s `setState` (modalSetState).
    if (_firstDateInRange == null) {
      // First tap of a new selection. This resets any existing range.
      _firstDateInRange = day;
      _startDate = day;
      _endDate = day;
    } else {
      // Second tap, completing the range.
      if (day.isBefore(_firstDateInRange!)) {
        _startDate = day;
        _endDate = _firstDateInRange;
      } else {
        _startDate = _firstDateInRange;
        _endDate = day;
      }
      // Reset for the next selection cycle. A third tap will start a new range.
      _firstDateInRange = null;
    }
  }

  // FIX: Replaced range check logic
  bool _isDayInRange(DateTime day) {
    // If we are in the middle of selecting a range (only first date is tapped),
    // only highlight that specific date.
    if (_firstDateInRange != null) {
      return DateUtils.isSameDay(day, _firstDateInRange);
    }

    // If no dates are set, nothing is in range.
    if (_startDate == null || _endDate == null) {
      return false;
    }

    // Normalize dates to ignore time component for accurate range checking.
    final cleanDay = DateUtils.dateOnly(day);
    final cleanStart = DateUtils.dateOnly(_startDate!);
    final cleanEnd = DateUtils.dateOnly(_endDate!);

    // Check if the day is within the selected range, inclusive.
    // This handles single-day selections as well, where cleanStart == cleanEnd.
    return (cleanDay.isAtSameMomentAs(cleanStart) || cleanDay.isAfter(cleanStart)) &&
           (cleanDay.isAtSameMomentAs(cleanEnd) || cleanDay.isBefore(cleanEnd));
  }

  Widget _buildAlarmToggle() {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: Text(
          'set alarm',
          style: theme.textTheme.headlineSmall,
        ),
        value: _isAlarmEnabled,
        onChanged: (bool value) {
          setState(() {
            _isAlarmEnabled = value;
            debugPrint('alarm enabled: $_isAlarmEnabled');
          });
        },
        activeColor: AppColors.primaryPink,
        inactiveThumbColor: theme.colorScheme.outline,
        secondary: const Icon(Icons.alarm_rounded, color: AppColors.primaryPink),
      ),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (widget.isNewEvent) // New Event
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        if (!widget.isNewEvent) // Existing Event
          TextButton(
            onPressed: () {
              if (widget.onDelete != null && widget.event != null) {
                notificationService.cancelNotification(widget.event!.id.hashCode);
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
}

// Custom Time Picker Widget (Copied from TaskFormModal)
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.softCream,
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