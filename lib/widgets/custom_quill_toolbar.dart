import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';
import '../utils/app_constants.dart';

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
    
    final toolbarColor = isDark ? const Color(0xFF2C2C2C) : AppColors.softCream;
    final unselectedIconColor = isDark ? AppColors.softCream : AppColors.primaryPink;

    return Localizations(
      locale: const Locale('en', 'US'),
      delegates: const [
        quill.FlutterQuillLocalizations.delegate,
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
            borderRadius: BorderRadius.circular(50),
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
                  // Bold
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.bold,
                    options: quill.QuillToolbarToggleStyleButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  // Italic
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.italic,
                    options: quill.QuillToolbarToggleStyleButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  // Underline
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.underline,
                    options: quill.QuillToolbarToggleStyleButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  
                  _buildDivider(isDark),

                  // Ordered List
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.ol,
                    options: quill.QuillToolbarToggleStyleButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  // Unordered List
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.ul,
                    options: quill.QuillToolbarToggleStyleButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  
                  // Checklist
                  quill.QuillToolbarToggleCheckListButton(
                    controller: controller,
                    options: quill.QuillToolbarToggleCheckListButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),

                  _buildDivider(isDark),

                  // Indent Increase
                  quill.QuillToolbarIndentButton(
                    controller: controller,
                    isIncrease: true,
                    options: quill.QuillToolbarIndentButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                  // Indent Decrease
                  quill.QuillToolbarIndentButton(
                    controller: controller,
                    isIncrease: false,
                    options: quill.QuillToolbarIndentButtonOptions(
                      iconSize: 20,
                      iconButtonFactor: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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