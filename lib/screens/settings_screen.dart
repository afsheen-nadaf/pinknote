import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_constants.dart';
import '../theme_mode_notifier.dart';
import '../services/services.dart';

class SettingsScreen extends StatefulWidget {
  final FirestoreService firestoreService;

  const SettingsScreen({super.key, required this.firestoreService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _exportTasks() async {
    try {
      final tasks = await widget.firestoreService.getTasks().first;
      if (tasks.isEmpty) {
        _showToast('you have no tasks to export.', isError: true);
        return;
      }

      final List<Map<String, dynamic>> jsonList =
          tasks.map((task) => task.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'pinknote_tasks_backup_${DateTime.now().toIso8601String().split('T').first}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Here is your pinknote tasks backup!');
    } catch (e) {
      debugPrint("Export Error: $e");
      _showToast('oops, something went wrong during export!', isError: true);
    }
  }

  void _showToast(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.accentGreen,
      ),
    );
  }

  Widget _buildFormattedText(String content, bool isDarkMode) {
    final List<String> lines = content.split('\n');
    final List<TextSpan> textSpans = [];

    final headingStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: isDarkMode ? AppColors.lightGrey : AppColors.textDark,
      height: 1.8,
    );
    final bodyStyle = GoogleFonts.poppins(
      color: isDarkMode ? AppColors.lightGrey.withOpacity(0.8) : AppColors.textDark.withOpacity(0.8),
      height: 1.5,
    );
    final smallStyle = GoogleFonts.poppins(
      color: isDarkMode ? AppColors.lightGrey.withOpacity(0.7) : AppColors.textDark.withOpacity(0.7),
      fontStyle: FontStyle.italic,
      height: 1.5,
    );
    final bulletStyle = GoogleFonts.poppins(
      color: isDarkMode ? AppColors.lightGrey.withOpacity(0.8) : AppColors.textDark.withOpacity(0.8),
      height: 1.6,
    );
    final boldStyle = GoogleFonts.poppins(
      color: isDarkMode ? AppColors.lightGrey.withOpacity(0.9) : AppColors.textDark.withOpacity(0.9),
      fontWeight: FontWeight.w800, // Bolder weight
      height: 1.5,
    );

    const headingEmojis = ['📦', '🔒', '☁️', '🍪', '🚫', '🧁', '🛠️', '🧼', '📉', '🧾'];

    for (var line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        textSpans.add(const TextSpan(text: '\n'));
      } else if (headingEmojis.any((emoji) => trimmedLine.endsWith(emoji))) {
        textSpans.add(TextSpan(text: '$line\n', style: headingStyle));
      } else if (line.startsWith('last updated:')) {
         textSpans.add(TextSpan(text: '$line\n\n', style: smallStyle));
      } else if (trimmedLine.startsWith('*')) {
         textSpans.add(TextSpan(text: '  • ${trimmedLine.substring(1).trim()}\n', style: bulletStyle));
      } else if (trimmedLine.startsWith('_') && trimmedLine.endsWith('_')) {
         textSpans.add(TextSpan(text: '${trimmedLine.substring(1, trimmedLine.length - 1)}\n', style: boldStyle));
      }
      else {
        textSpans.add(TextSpan(text: '$line\n', style: bodyStyle));
      }
    }

    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(children: textSpans),
    );
  }

  // --- MODIFIED: Dialog now has a fully scrollable content area ---
  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDarkMode ? AppColors.darkSurface : AppColors.softCream,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          contentPadding: EdgeInsets.zero, // Remove default padding
          content: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: isDarkMode ? AppColors.lightGrey : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                // Formatted Text
                _buildFormattedText(content, isDarkMode),
                // Close Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: Text(
                      'close',
                      style: GoogleFonts.poppins(
                          color: AppColors.primaryPink, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSettingsCard(
      {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4.0,
      shadowColor: theme.brightness == Brightness.dark
          ? Colors.black.withOpacity(0.5)
          : AppColors.shadowSoft.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: theme.brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.softCream,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeModeNotifier = Provider.of<ThemeModeNotifier>(context);

    const String privacyPolicyContent = '''
last updated: july 23, 2025
we care about your privacy — pinky promise! 💖

this privacy policy explains what we collect, how we use it, and how your info is kept safe when you use our app.

what we collect 📦
* your name and email (if you sign in)
* the tasks and categories you add
* any date and time info you use for reminders
* general device info (to help us improve the app)

how we use it 🔒
we use your info to:
* save your tasks
* help you stay organized
* send helpful reminders and suggestions ✨
_we never sell your data. ever._

where it's stored ☁️
your data is stored safely using firebase, with encryption and login protection. only you can see your data unless you choose to share it.

third-party stuff 🍪
we use things like google sign-in to make logging in easy. those services might collect data too, under their own privacy rules.

your choices 🚫
you can:
* ask us to delete your data
* sign out anytime
''';

    const String termsAndConditionsContent = '''
hi there! welcome to your little productivity space 💌

by using the app, you agree to these sweet and simple rules:

1. personal use only 🧁
this app is just for you and your cute plans. please don't use it for anything illegal, spammy, or harmful.

2. your account 🛠️
if you sign in:
* keep your login safe
* don't pretend to be someone else
* you're responsible for what you add

3. kind content only 🧼
please keep everything you write kind and respectful. if anything harmful is found, we may remove it.

4. no promises 📉
we try our best, but the app might have bugs sometimes. it's offered "as-is" without any fancy guarantees.

5. updates 🧾
we might update the app or these rules now and then. we'll let you know if anything major changes.
''';

    ThemeMode getMaterialThemeMode(AppThemeMode appThemeMode) {
      switch (appThemeMode) {
        case AppThemeMode.light:
          return ThemeMode.light;
        case AppThemeMode.dark:
          return ThemeMode.dark;
        case AppThemeMode.system:
          return ThemeMode.system;
      }
    }

    AppThemeMode getAppThemeMode(ThemeMode themeMode) {
      switch (themeMode) {
        case ThemeMode.light:
          return AppThemeMode.light;
        case ThemeMode.dark:
          return AppThemeMode.dark;
        case ThemeMode.system:
          return AppThemeMode.system;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [AppColors.darkBackground, AppColors.darkGrey]
              : [AppColors.softCream, AppColors.lightPeach],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.primaryPink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'settings',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: isDarkMode ? AppColors.lightGrey : AppColors.textDark,
                ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSettingsCard(
                      title: 'appearance',
                      children: [
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'system',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: ThemeMode.system,
                          groupValue:
                              getMaterialThemeMode(themeModeNotifier.themeMode),
                          onChanged: (ThemeMode? value) {
                            if (value != null) {
                              themeModeNotifier
                                  .setThemeMode(getAppThemeMode(value));
                            }
                          },
                          activeColor: AppColors.primaryPink,
                        ),
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'light',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: ThemeMode.light,
                          groupValue:
                              getMaterialThemeMode(themeModeNotifier.themeMode),
                          onChanged: (ThemeMode? value) {
                            if (value != null) {
                              themeModeNotifier
                                  .setThemeMode(getAppThemeMode(value));
                            }
                          },
                          activeColor: AppColors.primaryPink,
                        ),
                        RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'dark',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: ThemeMode.dark,
                          groupValue:
                              getMaterialThemeMode(themeModeNotifier.themeMode),
                          onChanged: (ThemeMode? value) {
                            if (value != null) {
                              themeModeNotifier
                                  .setThemeMode(getAppThemeMode(value));
                            }
                          },
                          activeColor: AppColors.primaryPink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      title: 'sound',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.volume_up_rounded,
                              color: AppColors.primaryPink),
                          title: Text(
                            'sound effects',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Switch(
                            value: soundService.isSoundEnabled,
                            onChanged: (bool value) {
                              setState(() {
                                soundService.setSoundPreference(value);
                              });
                            },
                            activeColor: AppColors.primaryPink,
                            inactiveThumbColor: AppColors.borderLight,
                          ),
                          onTap: () {
                            setState(() {
                              soundService.setSoundPreference(
                                  !soundService.isSoundEnabled);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      title: 'reminders',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.notifications_rounded,
                              color: AppColors.primaryPink),
                          title: Text(
                            'app reminders',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Switch(
                            value:
                                notificationService.isNotificationsEnabled(),
                            onChanged: (bool value) async {
                              await notificationService.setNotificationPreference(value);
                              setState(() {}); // Rebuild to reflect the change
                            },
                            activeColor: AppColors.primaryPink,
                            inactiveThumbColor: AppColors.borderLight,
                          ),
                          onTap: () async {
                            final bool currentValue = notificationService.isNotificationsEnabled();
                            await notificationService.setNotificationPreference(!currentValue);
                            setState(() {}); // Rebuild to reflect the change
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      title: 'backup / export tasks',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.file_download_outlined,
                              color: AppColors.primaryPink),
                          title: Text('export tasks to file',
                              style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: _exportTasks,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsCard(
                      title: 'legal',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.privacy_tip_outlined,
                              color: AppColors.primaryPink),
                          title: Text(
                            'privacy policy',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => _showInfoDialog(
                              'privacy policy 🌸', privacyPolicyContent),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.gavel_rounded,
                              color: AppColors.primaryPink),
                          title: Text(
                            'terms & conditions',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: isDarkMode
                                  ? AppColors.lightGrey
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => _showInfoDialog(
                              'terms & conditions 📜',
                              termsAndConditionsContent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}