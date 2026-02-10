import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../utils/app_constants.dart';

class CategoryHorizontalList extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final Function(Category) onCategoryTap;
  final Function(Category) onCategoryLongPress;
  final VoidCallback onAddCategoryTap;

  const CategoryHorizontalList({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryTap,
    required this.onCategoryLongPress,
    required this.onAddCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Existing Categories
          ...categories.map((category) {
            final isSelected = selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => onCategoryTap(category),
                onLongPress: () => onCategoryLongPress(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryPink,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    category.name.toLowerCase(),
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : AppColors.primaryPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          // "+ new" Button
          GestureDetector(
            onTap: onAddCategoryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkSurface : AppColors.softCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryPink.withOpacity(0.5),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryPink),
                  const SizedBox(width: 4),
                  Text(
                    'new',
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}