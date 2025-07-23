import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../utils/app_constants.dart';

class CategoryManagementModal extends StatefulWidget {
  final List<Category> availableCategories;
  final Function(Category) onAddCategory;
  final Function(Category) onUpdateCategory;
  final Function(String) onDeleteCategory;

  const CategoryManagementModal({
    super.key,
    required this.availableCategories,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
  });

  @override
  State<CategoryManagementModal> createState() => _CategoryManagementModalState();
}

class _CategoryManagementModalState extends State<CategoryManagementModal> {
  late TextEditingController _categoryNameController;
  Color _selectedColor = AppColors.categoryColors.first;
  Category? _editingCategory;

  @override
  void initState() {
    super.initState();
    _categoryNameController = TextEditingController();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  void _addOrUpdateCategory() {
    final String name = _categoryNameController.text.trim();
    if (name.isEmpty) return;

    if (_editingCategory == null) {
      // Add new category
      final newCategory = Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
        name: name,
        colorValue: _selectedColor.value,
      );
      widget.onAddCategory(newCategory);
    } else {
      // Update existing category
      final updatedCategory = _editingCategory!.copyWith(
        name: name,
        colorValue: _selectedColor.value,
      );
      widget.onUpdateCategory(updatedCategory);
    }
    _clearForm();
    Navigator.of(context).pop(); // Close modal after saving
  }

  void _editCategory(Category category) {
    setState(() {
      _editingCategory = category;
      _categoryNameController.text = category.name;
      _selectedColor = category.color;
    });
  }

  void _deleteCategory(String categoryId) {
    widget.onDeleteCategory(categoryId);
    _clearForm();
    Navigator.of(context).pop(); // Close modal after deleting
  }

  void _clearForm() {
    setState(() {
      _editingCategory = null;
      _categoryNameController.clear();
      _selectedColor = AppColors.categoryColors.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingCategory == null ? 'add new category' : 'edit category',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _categoryNameController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'category name',
                labelStyle: GoogleFonts.poppins(color: AppColors.primaryPink),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'choose color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: AppColors.categoryColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel', style: GoogleFonts.poppins(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                if (_editingCategory != null)
                  TextButton(
                    onPressed: () => _deleteCategory(_editingCategory!.id),
                    child: Text('delete', style: GoogleFonts.poppins(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addOrUpdateCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(_editingCategory == null ? 'add category' : 'save changes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'your categories',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.availableCategories.length,
              itemBuilder: (context, index) {
                final category = widget.availableCategories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 1.0,
                  color: category.color.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: category.color,
                      radius: 12,
                    ),
                    title: Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? AppColors.lightGrey : AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: isDarkMode ? AppColors.textLightDark : AppColors.textLight),
                      onPressed: () => _editCategory(category),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}