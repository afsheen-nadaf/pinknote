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
        onDeleteTask: task != null ? () => widget.firestoreService.deleteTask(task.id) : null,
        availableCategories: widget.availableCategories,
        onAddCategory: widget.onAddCategory,
        onUpdateCategory: widget.onUpdateCategory,
        onDeleteCategory: widget.onDeleteCategory,
      ),
    ).then((_) {
      // Unfocus any active text fields when the modal is closed to prevent the keyboard from reappearing.
      FocusManager.instance.primaryFocus?.unfocus();
    });
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

            final allTasks = snapshot.data!;
            final completedTasks = allTasks.where((task) => task.isCompleted).length;
            final totalTasks = allTasks.length;
            final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
            final filteredTasks = _showImportantOnly ? allTasks.where((t) => t.isImportant).toList() : allTasks;

            if (snapshot.hasData && _animationController.status == AnimationStatus.dismissed) {
              _animationController.forward();
            }

            if (totalTasks == 0) {
              return _buildEmptyState(
                icon: Icons.task_alt_rounded,
                title: 'all clear!',
                subtitle: 'add a new task to get started.',
              );
            } else if (completedTasks == totalTasks && totalTasks > 0) {
              return _buildEmptyState(
                icon: Icons.check_circle_rounded,
                title: 'all done!',
                subtitle: 'nothing left on the list — you crushed it!',
                iconColor: AppColors.accentGreen,
              );
            }

            return FadeTransition(
              opacity: _fadeInAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                       
                        const SizedBox(height: 20),
                        Padding(
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
                                    '$completedTasks of $totalTasks tasks completed (${(progress * 100).round()}%)',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                    color: _showImportantOnly ? AppColors.primaryPink : AppColors.borderLight,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    sliver: SliverReorderableList(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
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
                                key: ValueKey('${task.id}_${task.isCompleted}_${task.isImportant}'),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) {
                                  soundService.playSwipeDeleteSound();
                                  widget.firestoreService.deleteTask(task.id);
                                  ScaffoldMessenger.of(context)
                                    ..removeCurrentSnackBar()
                                    ..showSnackBar(SnackBar(content: Text('task "${task.title.toLowerCase()}" deleted.', style: GoogleFonts.poppins())));
                                },
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
                      onReorder: (oldI, newI) => _onReorder(oldI, newI, filteredTasks),
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
                  ),
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
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}