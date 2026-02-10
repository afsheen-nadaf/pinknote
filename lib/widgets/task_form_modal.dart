import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:chrono_dart/chrono_dart.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/services.dart';
import '../utils/app_constants.dart';
import '../widgets/category_form_modal.dart';
import '../widgets/subtask_form_modal.dart';

class TaskFormModal extends StatefulWidget {
  final Task? task;
  final Function(Task) onSave;
  final VoidCallback? onDeleteTask;
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;
  final FirestoreService firestoreService;

  const TaskFormModal({
    super.key,
    this.task,
    required this.onSave,
    this.onDeleteTask,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    required this.firestoreService,
  });

  @override
  State<TaskFormModal> createState() => _TaskFormModalState();
}

class _TaskFormModalState extends State<TaskFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  late String _selectedCategoryName;
  late List<Subtask> _subtasks;
  late bool _isImportant;
  late bool _isAlarmEnabled;

  DateTime? _detectedDateTime;
  bool _keepDetectedDateTime = true;

  String? _recurrenceUnit;
  late int _recurrenceValue;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _dueDate = task?.dueDate;
    _dueTime = task?.dueTime;
    _selectedCategoryName = task?.category ?? 'general';
    _subtasks = task?.subtasks.map((s) => s.copyWith()).toList() ?? [];
    _isImportant = task?.isImportant ?? false;
    _isAlarmEnabled = task?.isAlarmEnabled ?? true;

    _recurrenceUnit = task?.recurrenceUnit;
    _recurrenceValue = task?.recurrenceValue ?? 1;

    _titleController.addListener(_parseTextForDateTime);
    _notesController.addListener(_parseTextForDateTime);
    _parseTextForDateTime();
  }

  @override
  void dispose() {
    _titleController.removeListener(_parseTextForDateTime);
    _notesController.removeListener(_parseTextForDateTime);
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _parseTextForDateTime() {
    final text = '${_titleController.text} ${_notesController.text}'.trim();
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
          _keepDetectedDateTime = true;
        }
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      if (widget.task != null) {
        notificationService.cancelNotification(NotificationService.createIntIdFromString(widget.task!.id));
      }

      if (widget.task == null) {
        soundService.playAddTaskSound();
      }
      HapticFeedback.mediumImpact();
      final now = DateTime.now();
      final String taskId = widget.task?.id ?? now.millisecondsSinceEpoch.toString();
      final order = widget.task?.order ?? now.millisecondsSinceEpoch;

      final selectedCategory = widget.availableCategories.firstWhere(
        (cat) => cat.name == _selectedCategoryName,
        orElse: () => Category(id: 'general', name: 'general', colorValue: AppColors.primaryPink.value),
      );
      
      final DateTime? finalDueDate;
      final TimeOfDay? finalDueTime;

      if (_keepDetectedDateTime && _detectedDateTime != null) {
        finalDueDate = _detectedDateTime;
        finalDueTime = TimeOfDay.fromDateTime(_detectedDateTime!);
      } else {
        finalDueDate = _dueDate;
        finalDueTime = _dueTime;
      }

      final updatedTask = (widget.task ?? Task(id: taskId, title: '', order: order))
          .copyWith(
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        category: _selectedCategoryName,
        colorValue: selectedCategory.colorValue,
        dueDate: finalDueDate,
        dueTime: finalDueTime,
        subtasks: _subtasks,
        isImportant: _isImportant,
        isAlarmEnabled: _isAlarmEnabled,
        order: order,
        recurrenceUnit: _isAlarmEnabled ? _recurrenceUnit : null,
        recurrenceValue: _isAlarmEnabled ? _recurrenceValue : 1,
      );
      widget.onSave(updatedTask);

      if (_isAlarmEnabled && updatedTask.dueDate != null && updatedTask.dueTime != null) {
        final scheduledDateTime = DateTime(
          updatedTask.dueDate!.year,
          updatedTask.dueDate!.month,
          updatedTask.dueDate!.day,
          updatedTask.dueTime!.hour,
          updatedTask.dueTime!.minute,
        );

        notificationService.scheduleReminderNotification(
          id: NotificationService.createIntIdFromString(updatedTask.id),
          title: updatedTask.title,
          body: updatedTask.notes?.toLowerCase() ?? 'your scheduled task is due now.',
          scheduledDate: scheduledDateTime,
          context: context,
          type: 'task',
          recurrenceUnit: updatedTask.recurrenceUnit,
          recurrenceValue: updatedTask.recurrenceValue,
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
              _buildNotesField(),
              const SizedBox(height: 16),
              _buildDateTimeSuggestion(),
              const SizedBox(height: 24),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              _buildDateTimeSection(),
              const SizedBox(height: 16),
              _buildAlarmToggle(),
              const SizedBox(height: 24),
              _buildSubtasksSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
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

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (widget.task == null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        if (widget.task != null)
          TextButton(
            onPressed: () {
              // This call is now handled by the FirestoreService deleteTask method
              // notificationService.cancelNotification(NotificationService.createIntIdFromString(widget.task!.id));
              widget.onDeleteTask?.call();
              Navigator.pop(context);
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(widget.task == null ? 'add task' : 'save changes'),
        ),
      ],
    );
  }

  void _presentDateTimePicker() {
    setState(() => _keepDetectedDateTime = false);
    HapticFeedback.lightImpact();

    if (_dueDate == null) {
      setState(() {
        _dueDate = DateTime.now();
        _dueTime = TimeOfDay.now();
      });
    }

    DateTime initialDateTime = _dueDate ?? DateTime.now();
    TimeOfDay initialTimeOfDay = _dueTime ?? TimeOfDay.now();

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
                          _dueDate = null;
                          _dueTime = null;
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
                      flex: 3,
                      child: _CustomDatePicker(
                        initialDate: initialDateTime,
                        onDateChanged: (newDate) => setState(() => _dueDate = newDate),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _CustomTimePicker(
                        initialTime: initialTimeOfDay,
                        onTimeChanged: (newTime) => setState(() => _dueTime = newTime),
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
  
  void _showSubtaskFormModal({Subtask? subtask, int? index}) {
    soundService.playModalOpeningSound();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubtaskFormModal(
        subtask: subtask,
        onSave: (savedSubtask) {
          setState(() {
            if (index != null) {
              _subtasks[index] = savedSubtask;
            } else {
              soundService.playAddTaskSound();
              _subtasks.add(savedSubtask);
            }
          });
        },
      ),
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

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.task == null ? 'new task' : 'edit task', style: theme.textTheme.headlineMedium),
        IconButton(
          icon: Icon(_isImportant ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.accentYellow, size: 30),
          onPressed: () {
            soundService.playMarkAsImportantSound();
            setState(() => _isImportant = !_isImportant);
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
        labelText: 'task title',
        labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5)),
      ),
    );
  }

  Widget _buildNotesField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: 'notes',
        labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5)),
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
              firestoreService: widget.firestoreService,
              currentCategories: widget.availableCategories,
              existingCategories: widget.availableCategories,
              onSave: (newCategory) {
                widget.onAddCategory(newCategory);
                setState(() => _selectedCategoryName = newCategory.name);
              },
            ),
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outline)),
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
              ? Container(width: 10, height: 10, decoration: BoxDecoration(color: category.color, shape: BoxShape.circle))
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? category.color : theme.colorScheme.outline)),
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
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.softCream,
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
                    setState(() {
                      if (_selectedCategoryName == category.name) {
                        _selectedCategoryName = updatedCategory.name;
                      }
                    });
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


  Widget _buildDateTimeSection() {
    final theme = Theme.of(context);
    String dateText;
    bool isDateSet;

    if (_keepDetectedDateTime && _detectedDateTime != null) {
      dateText = DateFormat('EEE, MMM d \'at\' h:mm a').format(_detectedDateTime!).toLowerCase();
      isDateSet = true;
    } else if (_dueDate != null) {
      final now = DateTime.now();
      final isToday = _dueDate!.year == now.year && _dueDate!.month == now.month && _dueDate!.day == now.day;
      dateText = isToday ? DateFormat('\'today\', MMM d', 'en_US').format(_dueDate!).toLowerCase() : DateFormat('MMM d, yyyy', 'en_US').format(_dueDate!).toLowerCase();
      if (_dueTime != null) {
        dateText += ' at ${_dueTime!.format(context).toLowerCase()}';
      }
      isDateSet = true;
    } else {
      dateText = 'no due date';
      isDateSet = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('due date', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _presentDateTimePicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.colorScheme.outline, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: isDateSet ? AppColors.primaryPink : theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 12),
                Text(dateText, style: theme.textTheme.bodyMedium?.copyWith(color: isDateSet ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtasksSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('subtasks', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (_subtasks.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _subtasks.length,
            itemBuilder: (context, index) {
              final subtask = _subtasks[index];
              return Dismissible(
                key: ValueKey(subtask.id),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  soundService.playSwipeDeleteSound();
                  setState(() => _subtasks.removeAt(index));
                },
                background: Container(
                  decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(15)),
                  child: const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(right: 20.0), child: Icon(Icons.delete_sweep_rounded, color: Colors.white))),
                ),
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outline, width: 1.0)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: GestureDetector(
                      onTap: () => setState(() => _subtasks[index] = subtask.copyWith(isCompleted: !subtask.isCompleted)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: subtask.isCompleted ? AppColors.primaryPink : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: subtask.isCompleted ? AppColors.primaryPink : theme.colorScheme.outline, width: 2),
                        ),
                        child: subtask.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    ),
                    title: Text(subtask.title, style: theme.textTheme.bodyMedium?.copyWith(decoration: subtask.isCompleted ? TextDecoration.lineThrough : null)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                      onPressed: () {
                        soundService.playSwipeDeleteSound();
                        setState(() => _subtasks.removeAt(index));
                      },
                    ),
                    onTap: () => _showSubtaskFormModal(subtask: subtask, index: index),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('add subtask'),
          onPressed: () => _showSubtaskFormModal(),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryPink, side: const BorderSide(color: AppColors.primaryPink), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }
}

class _CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  const _CustomDatePicker({required this.initialDate, required this.onDateChanged});

  @override
  _CustomDatePickerState createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  late FixedExtentScrollController _dateController;
  late DateTime _selectedDate;
  final int _startYear = DateTime.now().year - 50;
  final int _endYear = DateTime.now().year + 50;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(_startYear, 1, 1);
    _endDate = DateTime(_endYear, 12, 31);
    _selectedDate = widget.initialDate;
    final int initialIndex = _selectedDate.difference(_startDate).inDays;
    _dateController = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _updateSelectedDate(int index) {
    setState(() {
      _selectedDate = _startDate.add(Duration(days: index));
      widget.onDateChanged(_selectedDate);
    });
  }

  Widget _buildWheel({required FixedExtentScrollController controller, required int itemCount, required IndexedWidgetBuilder itemBuilder, required ValueChanged<int> onSelectedItemChanged}) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40.0,
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: AppColors.primaryPink.withOpacity(0.1)),
      looping: true,
      children: List<Widget>.generate(itemCount, (index) => itemBuilder(context, index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final int totalDays = _endDate.difference(_startDate).inDays + 1;

    return Container(
      color: theme.colorScheme.surface,
      child: _buildWheel(
        controller: _dateController,
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final dateForDisplay = _startDate.add(Duration(days: index));
          String displayDate;
          if (dateForDisplay.year == now.year && dateForDisplay.month == now.month && dateForDisplay.day == now.day) {
            displayDate = 'today, ${DateFormat('MMM d', 'en_US').format(dateForDisplay).toLowerCase()}';
          } else {
            displayDate = DateFormat('MMM d, yyyy', 'en_US').format(dateForDisplay).toLowerCase();
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(displayDate, style: theme.textTheme.bodyLarge),
            ),
          );
        },
        onSelectedItemChanged: (index) => _updateSelectedDate(index),
      ),
    );
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
      itemExtent: 40.0,
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
              itemExtent: 40.0,
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