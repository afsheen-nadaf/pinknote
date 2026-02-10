import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_constants.dart'; // Assuming AppColors is here

class ColorPickerModal extends StatelessWidget {
  final bool isBackground;
  final Function(Color) onColorSelected;

  const ColorPickerModal({
    super.key,
    required this.isBackground,
    required this.onColorSelected,
  });

  // Curated Pastel Palette
  static const List<Color> _palette = [
    Color(0xFF000000), // Black (Reset/Default)
    Color(0xFFEF5350), // Muted Red
    Color(0xFFAB47BC), // Muted Purple
    Color(0xFF5C6BC0), // Muted Indigo
    Color(0xFF26A69A), // Teal
    Color(0xFF66BB6A), // Soft Green
    Color(0xFFD4E157), // Lime
    Color(0xFFFFCA28), // Amber
    Color(0xFF8D6E63), // Brown
    Color(0xFF78909C), // Blue Grey
  ];
  
  // Background specific pastels (lighter)
  static const List<Color> _bgPalette = [
    Color(0x00000000), // Transparent/None
    Color(0xFFFFEBEE), // Pink 50
    Color(0xFFF3E5F5), // Purple 50
    Color(0xFFE8EAF6), // Indigo 50
    Color(0xFFE0F2F1), // Teal 50
    Color(0xFFE8F5E9), // Green 50
    Color(0xFFF9FBE7), // Lime 50
    Color(0xFFFFF8E1), // Amber 50
    Color(0xFFEFEBE9), // Brown 50
    Color(0xFFECEFF1), // Blue Grey 50
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isBackground ? _bgPalette : _palette;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFF8E1), // AppColors.softCream equivalent
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBackground ? 'highlight color' : 'text color',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Quicksand', // Consistent font
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: colors.map((color) {
              return _buildColorOption(context, color);
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, Color color) {
    final isTransparent = color.value == 0;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onColorSelected(color);
        Navigator.pop(context);
      },
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: isTransparent
            ? const Icon(Icons.format_color_reset_rounded, size: 20, color: Colors.grey)
            : null,
      ),
    );
  }
}