import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/translations.dart'; // REQUIRED for FlutterQuillLocalizations
import 'package:flutter_localizations/flutter_localizations.dart';
import '../utils/app_constants.dart';
// import 'color_picker_modal.dart'; // Removed as color features are removed

class CustomQuillToolbar extends StatelessWidget {
  final quill.QuillController controller;

  const CustomQuillToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Aesthetic configuration
    final toolbarColor = isDark ? const Color(0xFF2C2C2C) : AppColors.softCream;
    final unselectedIconColor = isDark ? AppColors.softCream : AppColors.primaryPink; // Pink in light theme

    // Icon theme for styling
    final iconTheme = quill.QuillIconTheme(
      iconButtonSelectedData: quill.IconButtonData(
        color: Colors.white, // White icon when selected
        iconSize: 20,
      ),
      iconButtonUnselectedData: quill.IconButtonData(
        color: unselectedIconColor, // Pink in light, cream in dark
        iconSize: 20,
      ),
    );

    // WRAPPER: Provides localization to the toolbar subtree to prevent "null" errors
    return Localizations(
      locale: const Locale('en', 'US'),
      delegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryPink,
            primary: AppColors.primaryPink,
            onPrimary: Colors.white,
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: toolbarColor,
            borderRadius: BorderRadius.circular(50), // Pill shape
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Formatting Group ---
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.bold,
                  options: quill.QuillToolbarToggleStyleButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.italic,
                  options: quill.QuillToolbarToggleStyleButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.underline,
                  options: quill.QuillToolbarToggleStyleButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                
                _buildDivider(isDark),

                // --- Lists Group ---
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.ol,
                  options: quill.QuillToolbarToggleStyleButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: controller,
                  attribute: quill.Attribute.ul,
                  options: quill.QuillToolbarToggleStyleButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                
                quill.QuillToolbarToggleCheckListButton(
                  controller: controller,
                  options: quill.QuillToolbarToggleCheckListButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),

                _buildDivider(isDark),

                // --- Indentation ---
                quill.QuillToolbarIndentButton(
                  controller: controller,
                  isIncrease: true,
                  options: quill.QuillToolbarIndentButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
                quill.QuillToolbarIndentButton(
                  controller: controller,
                  isIncrease: false,
                  options: quill.QuillToolbarIndentButtonOptions(
                    iconTheme: iconTheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
  );
}

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? AppColors.softCream : AppColors.darkBorder,
    );
  }
}