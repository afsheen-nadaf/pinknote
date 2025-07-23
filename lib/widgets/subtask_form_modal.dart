import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/app_constants.dart';

class SubtaskFormModal extends StatefulWidget {
  final Subtask? subtask;
  final Function(Subtask) onSave;

  const SubtaskFormModal({super.key, this.subtask, required this.onSave});

  @override
  State<SubtaskFormModal> createState() => _SubtaskFormModalState();
}

class _SubtaskFormModalState extends State<SubtaskFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late bool _initialIsCompleted;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.subtask?.title ?? '');
    _initialIsCompleted = widget.subtask?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveSubtask() {
    if (_formKey.currentState!.validate()) {
      final savedSubtask = Subtask(
        id: widget.subtask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        isCompleted: _initialIsCompleted,
      );
      widget.onSave(savedSubtask);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                widget.subtask == null ? 'new subtask' : 'edit subtask',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'subtask title',
                  hintText: 'e.g., research a topic',
                  labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.checklist_rounded, color: AppColors.primaryPink),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'subtask title cannot be empty';
                  }
                  return null;
                },
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  // Changed color to be non-destructive
                  child: Text('cancel', style: theme.textTheme.labelLarge),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveSubtask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    widget.subtask == null ? 'add subtask' : 'save changes',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}