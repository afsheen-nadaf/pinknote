import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/services.dart';
import '../utils/app_constants.dart';

class TaskItemWidget extends StatelessWidget {
  final Task task;
  final VoidCallback onToggleComplete;
  final VoidCallback onEditTask;
  final VoidCallback onToggleImportance;
  final Function(int subtaskIndex) onToggleSubtaskComplete;
  final Color categoryColor;

  const TaskItemWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEditTask,
    required this.onToggleImportance,
    required this.onToggleSubtaskComplete,
    required this.categoryColor,
  });

  String _formatDate(BuildContext context) {
    if (task.dueDate == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String dateString;

    if (DateUtils.isSameDay(task.dueDate, today)) {
      dateString = 'today';
    } else {
      dateString = '${task.dueDate!.day}/${task.dueDate!.month}';
    }

    if (task.dueTime != null) {
      dateString += ', ${task.dueTime!.format(context)}';
    }
    return dateString;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onEditTask,
      borderRadius: BorderRadius.circular(15.0),
      child: Card(
        elevation: 4.0,
        shadowColor: categoryColor.withOpacity(0.3),
        color: categoryColor.withOpacity(isDarkMode ? 0.25 : 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: categoryColor.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              if (task.notes?.isNotEmpty ?? false) _buildNotesSection(context),
              if (task.subtasks.isNotEmpty) _buildSubtasksSection(context),
              _buildMetaChips(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleComplete,
          child: Container(
            padding: const EdgeInsets.all(4.0),
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isCompleted ? AppColors.primaryPink : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted
                      ? AppColors.primaryPink
                      : (isDarkMode ? theme.colorScheme.outline : Colors.white),
                  width: 2,
                ),
              ),
              child: task.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              task.title,
              style: theme.textTheme.titleMedium?.copyWith(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted
                    ? theme.colorScheme.onSurface.withOpacity(0.6)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (!task.isImportant) {
              soundService.playMarkAsImportantSound();
            }
            onToggleImportance();
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
            child: Icon(
              task.isImportant ? Icons.star_rounded : Icons.star_border_rounded,
              color: task.isImportant
                  ? AppColors.accentYellow
                  : (isDarkMode ? theme.colorScheme.outline : Colors.white),
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4, right: 36),
      child: Text(
        task.notes!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildSubtasksSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 10.0),
      child: Column(
        children: task.subtasks.asMap().entries.map((entry) {
          int idx = entry.key;
          Subtask subtask = entry.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onToggleSubtaskComplete(idx);
            },
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: subtask.isCompleted ? AppColors.primaryPink : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: subtask.isCompleted
                            ? AppColors.primaryPink
                            : (isDarkMode ? theme.colorScheme.outline : Colors.white),
                        width: 2,
                      ),
                    ),
                    child: subtask.isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subtask.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                        color: subtask.isCompleted
                            ? theme.colorScheme.onSurface.withOpacity(0.6)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetaChips(BuildContext context) {
    final hasDueDate = task.dueDate != null;
    final hasCategory = task.category != 'general';

    if (!hasDueDate && !hasCategory) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 40.0, top: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          if (hasDueDate)
            _buildInfoChip(
              context: context,
              icon: Icons.calendar_today_rounded,
              text: _formatDate(context),
              color: AppColors.primaryPink,
            ),
          if (hasCategory)
            _buildCategoryInfoChip(
              context: context,
              text: task.category,
              color: categoryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required BuildContext context, required IconData icon, required String text, required Color color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryInfoChip({required BuildContext context, required String text, required Color color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}