import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill; // Import Quill to parse Delta
import '../models/note.dart';
import '../utils/app_constants.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isListMode;
  final Color? categoryColor; 
  final String? categoryName;
  final Color? borderColor; // Border color - pinned or category color

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    this.isListMode = false,
    this.categoryColor,
    this.categoryName,
    this.borderColor, // Optional border color
  });

  // Helper to extract plain text from Quill Delta JSON
  String _getPlainText(String content) {
    try {
      final json = jsonDecode(content);
      final doc = quill.Document.fromJson(json);
      return doc.toPlainText().trim();
    } catch (e) {
      // If parsing fails (maybe it's old plain text), return as is
      return content; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Determine card color
    Color cardColor = isDarkMode ? AppColors.darkSurface : Color(note.colorValue);
    if (isDarkMode && note.colorValue != 0xFFFFF8E1) {
       cardColor = Color(note.colorValue).withOpacity(0.15);
    }

    final plainTextContent = _getPlainText(note.content);

    return GestureDetector(
      onTap: note.isLocked ? onTap : onTap,
      onLongPress: onLongPress,
      child: Card(
        color: cardColor,
        elevation: 2,
        shadowColor: AppColors.shadowSoft.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: borderColor != null
            ? BorderSide(color: borderColor!, width: 2)
            : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Critical for MasonryGridView
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'untitled',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icons Row (Lock/Favorite + Pin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.isLocked)
                        const Icon(Icons.lock_rounded, size: 16, color: AppColors.textLight)
                      else if (note.isFavorite)
                        const Icon(Icons.favorite_rounded, size: 16, color: AppColors.errorRed),
                      
                      // Pink Pin Icon on Top Right
                      if (note.isPinned) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primaryPink),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Content Area
              note.isLocked
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Icon(Icons.lock_outline_rounded, 
                          size: 32, 
                          color: theme.colorScheme.onSurface.withOpacity(0.3)
                        ),
                      ),
                    )
                  : Text(
                      plainTextContent, // Use parsed plain text
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: (isDarkMode ? Colors.white : AppColors.textDark).withOpacity(0.7),
                        height: 1.4,
                      ),
                      maxLines: isListMode ? 2 : 8,
                      overflow: TextOverflow.ellipsis,
                    ),

              // Category Indicator with Name & User's Exact Color
              if (note.categoryId != null && !note.isLocked && categoryColor != null && categoryName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor!.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoryColor!.withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: categoryColor, 
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          categoryName!.toLowerCase(),
                          style: GoogleFonts.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}