import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/services.dart';
import '../utils/app_constants.dart';

class CategoryFormModal extends StatefulWidget {
  final Category? category; // Null for new, Category object for editing
  final List<Category> existingCategories; // Needed to check for duplicates
  final Function(Category) onSave;

  const CategoryFormModal({
    super.key,
    this.category,
    required this.existingCategories,
    required this.onSave, required FirestoreService firestoreService, required List<Category> currentCategories,
  });

  @override
  State<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends State<CategoryFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? AppColors.categoryColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      // Play sound only for new categories
      if (widget.category == null) {
        soundService.playAddTaskSound();
      }

      final savedCategory = Category(
        id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        colorValue: _selectedColor.value,
      );

      widget.onSave(savedCategory);
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
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.5),
          width: 1.0,
        ),
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
                widget.category == null ? 'new category' : 'edit category',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: 'category name',
                  hintText: 'e.g., work, personal, home',
                  labelStyle: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryPink),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
                  ),
                  prefixIcon: const Icon(Icons.category_rounded, color: AppColors.primaryPink),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'category name cannot be empty';
                  }
                  
                  final inputName = value.trim().toLowerCase();
                  
                  // Check if the name already exists in the list
                  // We ignore the check if the name belongs to the category we are currently editing
                  final isDuplicate = widget.existingCategories.any((cat) => 
                    cat.name.toLowerCase() == inputName && cat.id != widget.category?.id
                  );

                  if (isDuplicate) {
                    return "'$inputName' already exists. try a different name";
                  }

                  return null;
                },
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'select color',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: AppColors.categoryColors.map((color) {
                final bool isSelected = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryPink : theme.colorScheme.outline.withOpacity(0.5),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel', style: theme.textTheme.labelLarge),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    widget.category == null ? 'add category' : 'save changes',
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