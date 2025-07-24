// ignore_for_file: undefined_hidden_name

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
  bool _showImportantOnly = false;
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
            
            final incompleteTasks = allTasks.where((task) => !task.isCompleted).toList();
            final completedTasks = allTasks.where((task) => task.isCompleted).toList();

            final totalTasks = allTasks.length;
            final progress = totalTasks > 0 ? completedTasks.length / totalTasks : 0.0;
            final filteredIncompleteTasks = _showImportantOnly ? incompleteTasks.where((t) => t.isImportant).toList() : incompleteTasks;

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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilterChip(
                                    showCheckmark: false,
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: _showImportantOnly ? Colors.white : AppColors.primaryPink,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'important tasks',
                                          style: GoogleFonts.poppins(
                                            color: _showImportantOnly ? Colors.white : AppColors.primaryPink,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: _showImportantOnly,
                                    onSelected: (bool selected) {
                                      setState(() {
                                        _showImportantOnly = selected;
                                      });
                                    },
                                    selectedColor: AppColors.primaryPink,
                                    backgroundColor: theme.cardColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: _showImportantOnly ? AppColors.primaryPink : AppColors.borderLight.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
        onPressed: () => _showTaskFormModal(),
        backgroundColor: AppColors.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 10.0,
        label: Text(
          'add new task',
          style: theme.textTheme.labelLarge?.copyWith(color: isDarkMode ? Colors.black : Colors.white),
        ),
        icon: Icon(Icons.add_task_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

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