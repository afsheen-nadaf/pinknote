// ignore_for_file: undefined_hidden_name

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart'; // Added for date formatting
import '../models/task.dart';
import '../models/category.dart';
import '../utils/app_constants.dart';
import '../widgets/task_item_widget.dart' hide TaskFormModal;
import '../services/services.dart';
import '../widgets/task_form_modal.dart';
import 'package:google_fonts/google_fonts.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.firestoreService,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
  });

  final FirestoreService firestoreService;
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  // --- MODIFIED: State variables for filtering and sorting ---
  bool _showImportantOnly = false;
  String? _selectedCategory;
  bool? _dateSortAscending; // null = no sort, true = ascending, false = descending
  // DateTime? _selectedDate; // MODIFICATION: Added for week day filter
  // DateTime _focusedDateForWeekView = DateTime.now(); // MODIFICATION: For week swiping
  // --- End of modification ---

  late final AnimationController _animationController;
  late final Animation<double> _fadeInAnimation;
  final Set<String> _dismissedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showTaskFormModal({Task? task}) {
    soundService.playModalOpeningSound();
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskFormModal(
        firestoreService: widget.firestoreService,
        task: task,
        onSave: (updatedTask) {
          if (task == null) {
            widget.firestoreService.addTask(updatedTask);
            soundService.playAddTaskSound();
          } else {
            widget.firestoreService.updateTask(updatedTask);
          }
        },
        onDeleteTask: task != null ? () => _deleteTaskWithUndo(task) : null,
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
      ),
    ).then((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _deleteTaskWithUndo(Task task) {
    soundService.playSwipeDeleteSound();
    
    setState(() {
      _dismissedTaskIds.add(task.id);
    });
    
    widget.firestoreService.deleteTask(task.id);

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'task "${task.title.toLowerCase()}" deleted.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
        action: SnackBarAction(
          label: 'undo',
          textColor: AppColors.primaryPink,
          onPressed: () {
            _undoDelete(task);
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

  void _undoDelete(Task task) {
    setState(() {
      _dismissedTaskIds.remove(task.id);
    });
    widget.firestoreService.addTask(task);
  }

  Future<void> _onReorder(int oldIndex, int newIndex, List<Task> tasks) async {
    final reorderedTasks = List<Task>.from(tasks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Task item = reorderedTasks.removeAt(oldIndex);
    reorderedTasks.insert(newIndex, item);
    await widget.firestoreService.reorderTasks(reorderedTasks);
  }

  // --- MODIFIED: Methods for handling filters ---

  void _selectCategoryFilter() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkGrey : AppColors.softCream,
          title: const Text(
            'filter by category',
            style: TextStyle(color: AppColors.primaryPink),
          ),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableCategories.length,
              itemBuilder: (context, index) {
                final category = widget.availableCategories[index];
                // MODIFICATION: Added leading color circle to list tile
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.color,
                    radius: 12,
                  ),
                  title: Text(category.name),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.name;
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _showImportantOnly = false;
      _selectedCategory = null;
      _dateSortAscending = null;
      // _selectedDate = null; // MODIFICATION: Clear selected date
      // _focusedDateForWeekView = DateTime.now(); // MODIFICATION: Reset week view
    });
  }
  // --- End of modification ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<List<Task>>(
          stream: widget.firestoreService.getTasks(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('error: ${snapshot.error}', style: GoogleFonts.poppins(color: AppColors.errorRed)));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));

            final allTasks = snapshot.data!.where((task) => !_dismissedTaskIds.contains(task.id)).toList();
            
            // --- MODIFIED: Apply all active filters and sorting ---
            var filteredIncompleteTasks = allTasks.where((task) => !task.isCompleted).toList();
            if (_showImportantOnly) {
              filteredIncompleteTasks = filteredIncompleteTasks.where((t) => t.isImportant).toList();
            }
            if (_selectedCategory != null) {
              filteredIncompleteTasks = filteredIncompleteTasks.where((t) => t.category == _selectedCategory).toList();
            }
            // MODIFICATION: Added filtering by selected date
            // if (_selectedDate != null) {
            //   filteredIncompleteTasks = filteredIncompleteTasks.where((task) {
            //     if (task.dueDate == null) return false;
            //     return task.dueDate!.year == _selectedDate!.year &&
            //            task.dueDate!.month == _selectedDate!.month &&
            //            task.dueDate!.day == _selectedDate!.day;
            //   }).toList();
            // }
            if (_dateSortAscending != null) {
              filteredIncompleteTasks.sort((a, b) {
                if (a.dueDate == null && b.dueDate == null) return 0;
                if (a.dueDate == null) return 1;
                if (b.dueDate == null) return -1;
                return _dateSortAscending! ? a.dueDate!.compareTo(b.dueDate!) : b.dueDate!.compareTo(a.dueDate!);
              });
            }
            // --- End of modification ---

            final completedTasks = allTasks.where((task) => task.isCompleted).toList();
            final totalTasks = allTasks.length;
            final progress = totalTasks > 0 ? completedTasks.length / totalTasks : 0.0;

            if (snapshot.hasData && _animationController.status == AnimationStatus.dismissed) {
              _animationController.forward();
            }

            if (totalTasks == 0) {
              return _buildEmptyState(
                icon: Icons.task_alt_rounded,
                title: 'all clear!',
                subtitle: 'add a new task to get started.',
              );
            }

            return FadeTransition(
              opacity: _fadeInAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4.0,
                        shadowColor: AppColors.shadowSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: BorderSide(color: AppColors.primaryPink.withOpacity(0.5), width: 2),
                        ),
                        color: theme.cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bar_chart_rounded, color: theme.colorScheme.onSurface, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'overall progress',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPink.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.borderLight.withOpacity(0.5),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
                                  borderRadius: BorderRadius.circular(10),
                                  minHeight: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${completedTasks.length} of $totalTasks tasks completed (${(progress * 100).round()}%)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // MODIFICATION: Added week view widget
                  // SliverToBoxAdapter(
                  //   child: _buildWeekView(),
                  // ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Card(
                        elevation: 4.0,
                        shadowColor: AppColors.shadowSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: BorderSide(color: AppColors.borderLight.withOpacity(0.5), width: 1),
                        ),
                        color: theme.cardColor,
                        child: Column(
                          children: [
                            // --- MODIFIED: Replaced filter bar with a single filter button ---
                            _buildFilterButton(),
                            // --- End of modification ---
                            if (filteredIncompleteTasks.isEmpty && completedTasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: _buildEmptyState(
                                  icon: Icons.check_circle_rounded,
                                  title: 'all done!',
                                  subtitle: 'nothing left on the list — you crushed it!',
                                  iconColor: AppColors.accentGreen,
                                ),
                              ),
                            ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredIncompleteTasks.length,
                              itemBuilder: (context, index) {
                                final task = filteredIncompleteTasks[index];
                                final taskCategory = widget.availableCategories.firstWhere(
                                  (cat) => cat.name == task.category,
                                  orElse: () => Category(id: 'default', name: 'general', colorValue: AppColors.primaryPink.value),
                                );
                                return ReorderableDelayedDragStartListener(
                                  key: ValueKey(task.id),
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20.0),
                                      child: Dismissible(
                                        key: ObjectKey(task),
                                        direction: DismissDirection.endToStart,
                                        onDismissed: (_) => _deleteTaskWithUndo(task),
                                        background: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.errorRed,
                                            borderRadius: BorderRadius.circular(20.0),
                                          ),
                                          child: const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(right: 20.0), child: Icon(Icons.delete_sweep_rounded, color: Colors.white))),
                                        ),
                                        child: TaskItemWidget(
                                          task: task,
                                          onToggleComplete: () {
                                            if (!task.isCompleted) {
                                              soundService.playTaskCompletedSound();
                                            }
                                            HapticFeedback.lightImpact();
                                            widget.firestoreService.toggleTaskComplete(task.id, !task.isCompleted);
                                          },
                                          onEditTask: () => _showTaskFormModal(task: task),
                                          onToggleImportance: () {
                                            soundService.playMarkAsImportantSound();
                                            HapticFeedback.mediumImpact();
                                            widget.firestoreService.toggleTaskImportance(task.id, !task.isImportant);
                                          },
                                          onToggleSubtaskComplete: (subtaskIndex) => widget.firestoreService.toggleSubtaskComplete(task.id, subtaskIndex),
                                          categoryColor: taskCategory.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onReorder: (oldI, newI) => _onReorder(oldI, newI, filteredIncompleteTasks),
                              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (BuildContext context, Widget? child) {
                                    final double animValue = Curves.easeInOut.transform(animation.value);
                                    final double elevation = lerpDouble(0, 8, animValue)!;
                                    final double scale = lerpDouble(1.0, 1.02, animValue)!;
                                    return Transform.scale(
                                      scale: scale,
                                      child: Card(
                                        elevation: elevation,
                                        shadowColor: AppColors.shadowSoft.withOpacity(0.3),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        color: Colors.transparent,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (completedTasks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Card(
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
                                  const Icon(
                                    Icons.inventory_2,
                                    color: AppColors.primaryPink,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'task archive',
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
                                    itemCount: completedTasks.length,
                                    itemBuilder: (context, index) {
                                      final task = completedTasks[index];
                                      final taskCategory = widget.availableCategories.firstWhere(
                                        (cat) => cat.name == task.category,
                                        orElse: () => Category(id: 'default', name: 'general', colorValue: AppColors.primaryPink.value),
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15.0),
                                          child: Dismissible(
                                            key: ObjectKey(task),
                                            direction: DismissDirection.endToStart,
                                            onDismissed: (_) => _deleteTaskWithUndo(task),
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
                                              child: TaskItemWidget(
                                                task: task,
                                                onToggleComplete: () => widget.firestoreService.toggleTaskComplete(task.id, !task.isCompleted),
                                                onEditTask: () => _showTaskFormModal(task: task),
                                                onToggleImportance: () => widget.firestoreService.toggleTaskImportance(task.id, !task.isImportant),
                                                onToggleSubtaskComplete: (subtaskIndex) => widget.firestoreService.toggleSubtaskComplete(task.id, subtaskIndex),
                                                categoryColor: taskCategory.color,
                                              ),
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
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks_fab_main', // Unique Tag to prevent conflicts
        onPressed: () => _showTaskFormModal(),
        backgroundColor: AppColors.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 10.0,
        label: Text(
          'add task',
          style: theme.textTheme.labelLarge?.copyWith(color: isDarkMode ? Colors.black : Colors.white),
        ),
        icon: Icon(Icons.add_task_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  

  // --- MODIFICATION: Added week view widget ---
  /*
  Widget _buildWeekView() {
    final today = DateTime.now();
    final startOfWeek = _focusedDateForWeekView.subtract(Duration(days: _focusedDateForWeekView.weekday - 1));
    final weekDates = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // MODIFICATION: Center the items
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryPink), // MODIFICATION: Color
                onPressed: () {
                  setState(() {
                    _focusedDateForWeekView = DateTime(_focusedDateForWeekView.year, _focusedDateForWeekView.month - 1, 1);
                  });
                },
              ),
              Text(
                DateFormat('MMM yyyy').format(_focusedDateForWeekView).toLowerCase(), // MODIFICATION: Format and lowercase
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryPink), // MODIFICATION: Color
                onPressed: () {
                  setState(() {
                    _focusedDateForWeekView = DateTime(_focusedDateForWeekView.year, _focusedDateForWeekView.month + 1, 1);
                  });
                },
              ),
            ],
          ),
        ),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < 0) {
              setState(() {
                _focusedDateForWeekView = _focusedDateForWeekView.add(const Duration(days: 7));
              });
            } else if (details.primaryVelocity! > 0) {
              setState(() {
                _focusedDateForWeekView = _focusedDateForWeekView.subtract(const Duration(days: 7));
              });
            }
          },
          child: Container(
            height: 65,
            child: Center(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: weekDates.length,
                itemBuilder: (context, index) {
                  final date = weekDates[index];
                  final isSelected = _selectedDate != null &&
                      date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;
                  final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDate = null;
                        } else {
                          _selectedDate = date;
                        }
                      });
                    },
                    child: Container(
                      width: 45,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryPink : Colors.transparent,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: isToday && !isSelected ? AppColors.primaryPink : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('E').format(date).toLowerCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected ? AppColors.primaryPink : (isDarkMode ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
  */

  // --- MODIFIED: Widget for the new filter button and menu ---
  Widget _buildFilterButton() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bool isAnyFilterActive = _showImportantOnly || _selectedCategory != null || _dateSortAscending != null; // || _selectedDate != null;
    final filterTextColor = isDarkMode ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isAnyFilterActive)
            ActionChip(
              avatar: const Icon(Icons.clear_rounded, size: 18, color: AppColors.primaryPink),
              label: Text('clear filters', style: TextStyle(color: filterTextColor)),
              onPressed: _clearFilters,
              shape: StadiumBorder(
                side: BorderSide(color: AppColors.primaryPink.withOpacity(0.8), width: 1.5)
              ),
            ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            color: isDarkMode ? AppColors.darkGrey : AppColors.softCream,
            onSelected: (value) {
              if (!mounted) return;

              if (value == 'category') {
                Future.delayed(const Duration(milliseconds: 50), _selectCategoryFilter);
              } else {
                setState(() {
                  switch (value) {
                    case 'important':
                      _showImportantOnly = !_showImportantOnly;
                      break;
                    case 'date_asc':
                      _dateSortAscending = true;
                      break;
                    case 'date_desc':
                      _dateSortAscending = false;
                      break;
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'important',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.accentYellow, size: 20),
                    SizedBox(width: 12),
                    Text('important'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'category',
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, color: AppColors.primaryPink, size: 20),
                    SizedBox(width: 12),
                    Text('category'),
                  ],
                ),
              ),
              // MODIFICATION: Removed 'enabled: false' to make icons fully opaque
              PopupMenuItem<String>(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.accentBlue, size: 20),
                    const SizedBox(width: 12),
                    Text('date', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.of(context).pop('date_asc'),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_upward_rounded, color: AppColors.accentGreen),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop('date_desc'),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_downward_rounded, color: AppColors.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Chip(
              // MODIFICATION: Set filter icon color to be pink always
              avatar: const Icon(
                Icons.filter_list_rounded,
                color: AppColors.primaryPink,
              ),
              label: Text('filter', style: TextStyle(color: filterTextColor)),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.borderLight.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- End of added widget ---

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = AppColors.primaryPink,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}