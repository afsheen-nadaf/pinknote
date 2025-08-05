// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import WelcomeScreen to navigate to it
import 'package:pinknote/screens/welcome_screen.dart';
import '../utils/app_constants.dart';
import '../models/task.dart';
import '../models/category.dart';
import 'dart:async';
import '../services/services.dart';

class ProfileScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final List<Category> availableCategories;

  const ProfileScreen({
    super.key,
    required this.firestoreService,
    required this.availableCategories,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  User? _currentUser;
  Set<String> _unlockedBadgeIds = {};
  int _previousTotalTasks = 0;
  int _previousCompletedTasks = -1;
  int _previousCategoryCount = 0;
  late StreamSubscription<Set<String>> _badgesSubscription;
  late StreamSubscription<Map<String, dynamic>> _userProfileSubscription;

  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  Color _currentAvatarColor = AppColors.primaryPink.withOpacity(0.2);
  IconData _currentAvatarIcon = Icons.person_rounded;
  DateTime? _birthday;

  final List<IconData> _fruitIcons = const [
    Icons.apple_rounded,
    Icons.emoji_food_beverage_rounded,
    Icons.local_florist_rounded,
    Icons.bolt_rounded,
    Icons.egg_rounded,
    Icons.fastfood_rounded,
    Icons.restaurant_menu_rounded,
    Icons.icecream_rounded,
    Icons.cake_rounded,
    Icons.cake_outlined,
  ];


  static const String _firstTaskBadgeId = 'first_task_done';
  static const String _clockedInBadgeId = 'clocked_in';
  static const String _strawberryStreakBadgeId = 'strawberry_streak_7_days';
  static const String _earlyRiserBadgeId = 'early_iser';
  static const String _categoryMasterBadgeId = 'category_master';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final Set<String> _newlyUnlockedBadgesThisCycle = {};


  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: '');
    _emailController = TextEditingController(text: '');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (_currentUser?.email != null) {
            _emailController.text = _currentUser!.email!;
          }
        });
        if (_currentUser != null) {
          _listenToUserProfileData();
        }
      }
    });


    _badgesSubscription = widget.firestoreService.getUnlockedBadgesStream().listen((badgeIds) {
      if (mounted) {
        setState(() {
          _unlockedBadgeIds = badgeIds;
          debugPrint('loaded unlocked badges from firestore: $_unlockedBadgeIds');
        });
      }
    });
  }

  void _listenToUserProfileData() {
    _userProfileSubscription = widget.firestoreService.getUserProfileStream().listen((profileData) {
      if (mounted) {
        setState(() {
          if (profileData.containsKey('avatarColorValue')) {
            _currentAvatarColor = Color(profileData['avatarColorValue'] as int);
          }
          if (profileData.containsKey('avatarIconCodePoint')) {
            _currentAvatarIcon = IconData(profileData['avatarIconCodePoint'] as int, fontFamily: 'MaterialIcons');
          }
          if (profileData.containsKey('email')) {
            _emailController.text = profileData['email'] as String;
          } else if (_currentUser?.email != null) {
            _emailController.text = _currentUser!.email!;
          }
          if (profileData.containsKey('displayName')) {
            final newName = profileData['displayName'] as String;
            if (_displayNameController.text != newName) {
              _displayNameController.text = newName;
            }
          } else if (_currentUser?.displayName != null) {
            _displayNameController.text = _currentUser!.displayName!;
          }
          if (profileData.containsKey('birthday') && profileData['birthday'] != null) {
            _birthday = (profileData['birthday'] as Timestamp).toDate();
          } else {
            _birthday = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _badgesSubscription.cancel();
    _userProfileSubscription.cancel();
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildProfileCard({required String title, required Widget content}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4.0,
      shadowColor: AppColors.shadowSoft.withOpacity(isDarkMode ? 0.6 : 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  void _checkAndUnlockBadges(int totalTasks, int completedTasks, int longestStreak, List<Task> allTasks) {
    _newlyUnlockedBadgesThisCycle.clear();

    final Set<String> badgesBeforeCheck = Set.from(_unlockedBadgeIds);

    debugPrint('--- badge check start ---');
    debugPrint('current totaltasks: $totalTasks, completedtasks: $completedTasks, _previoustotaltasks: $_previousTotalTasks');
    debugPrint('unlocked badges before check: $_unlockedBadgeIds');

    if (completedTasks >= 1 && !badgesBeforeCheck.contains(_firstTaskBadgeId)) {
      debugPrint('condition met for first task done badge!');
      _unlockedBadgeIds.add(_firstTaskBadgeId);
      _newlyUnlockedBadgesThisCycle.add(_firstTaskBadgeId);
    }

    if (!badgesBeforeCheck.contains(_clockedInBadgeId)) {
      final hasCompletedScheduledTask = allTasks.any((task) =>
          task.isCompleted && task.dueDate != null && task.dueTime != null);
      if (hasCompletedScheduledTask) {
        debugPrint('condition met for clocked in badge!');
        _unlockedBadgeIds.add(_clockedInBadgeId);
        _newlyUnlockedBadgesThisCycle.add(_clockedInBadgeId);
      }
    }

    if (longestStreak >= 7 && !badgesBeforeCheck.contains(_strawberryStreakBadgeId)) {
      debugPrint('condition met for strawberry streak badge!');
      _unlockedBadgeIds.add(_strawberryStreakBadgeId);
      _newlyUnlockedBadgesThisCycle.add(_strawberryStreakBadgeId);
    }

    if (!badgesBeforeCheck.contains(_earlyRiserBadgeId)) {
      final hasEarlyTask = allTasks.any((task) {
        if (task.isCompleted && task.dueTime != null) {
          return task.dueTime!.hour < 9;
        }
        return false;
      });
      if (hasEarlyTask) {
        debugPrint('condition met for early riser badge!');
        _unlockedBadgeIds.add(_earlyRiserBadgeId);
        _newlyUnlockedBadgesThisCycle.add(_earlyRiserBadgeId);
      }
    }

    final userCreatedCategories = widget.availableCategories.where((c) => c.name.toLowerCase() != 'general').length;
    if (userCreatedCategories >= 3 && !badgesBeforeCheck.contains(_categoryMasterBadgeId)) {
      debugPrint('condition met for category master badge!');
      _unlockedBadgeIds.add(_categoryMasterBadgeId);
      _newlyUnlockedBadgesThisCycle.add(_categoryMasterBadgeId);
    }

    if (_newlyUnlockedBadgesThisCycle.isNotEmpty) {
      setState(() {
      });
      widget.firestoreService.saveUnlockedBadges(_unlockedBadgeIds);
      soundService.playBadgeUnlockedSound();

      for (String badgeId in _newlyUnlockedBadgesThisCycle) {
        if (badgeId == _firstTaskBadgeId) {
          _showFirstTaskCongratulationDialog();
        } else if (badgeId == _clockedInBadgeId) {
          _showBadgeDetailsDialog(
            text: 'clocked in',
            tagline: 'your first scheduled task, right on time!',
            icon: Icons.access_time_rounded,
            color: AppColors.accentCoral,
            isUnlocked: true,
          );
        } else if (badgeId == _categoryMasterBadgeId) {
          _showBadgeDetailsDialog(
            text: 'category master',
            tagline: 'your life’s officially organized into cute little boxes.',
            icon: Icons.folder_rounded,
            color: AppColors.accentGreen,
            isUnlocked: true,
          );
        }
      }
    }

    _previousTotalTasks = totalTasks;
    _previousCompletedTasks = completedTasks;
    _previousCategoryCount = widget.availableCategories.length;
    debugPrint('--- badge check end ---');
  }

  void _showFirstTaskCongratulationDialog() {
    _animationController.forward(from: 0.0);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: child,
        );
      },
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPink.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildCircularBadgeDisplay(
                      icon: Icons.cake_rounded,
                      text: 'first task done!',
                      color: AppColors.accentYellow,
                      isUnlocked: true,
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'congratulations!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'you just earned your first badge! keep up the good work!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'awesome!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBadgeDetailsDialog({
    required String text,
    required String tagline,
    required IconData icon,
    required Color color,
    required bool isUnlocked,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPink.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCircularBadgeDisplay(
                    icon: icon,
                    text: text,
                    color: color,
                    isUnlocked: isUnlocked,
                    size: 120,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isUnlocked ? 'badge unlocked!' : 'badge locked',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? AppColors.primaryPink : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isUnlocked ? tagline : 'keep working to unlock this badge!',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'got it!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularBadgeDisplay({
    required IconData icon,
    required String text,
    required Color color,
    required bool isUnlocked,
    double size = 100,
  }) {
    final Color displayColor = isUnlocked ? color : Colors.grey;
    final Color textColor = isUnlocked ? color : Colors.grey.shade600;
    final Color backgroundColor = isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1);
    final Color borderColor = isUnlocked ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: size * 0.4, color: displayColor),
          const SizedBox(height: 5),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: size * 0.12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileModal() {
    String tempDisplayName = _displayNameController.text;
    String tempEmail = _emailController.text;
    Color tempAvatarColor = _currentAvatarColor;
    IconData tempAvatarIcon = _currentAvatarIcon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'edit profile',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: tempDisplayName,
                      onChanged: (value) => tempDisplayName = value,
                      style: theme.textTheme.bodyLarge,
                      cursorColor: AppColors.primaryPink,
                      decoration: InputDecoration(
                        labelText: 'display name',
                        labelStyle: GoogleFonts.poppins(color: AppColors.primaryPink),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.4), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: tempEmail,
                      onChanged: (value) => tempEmail = value,
                      style: theme.textTheme.bodyLarge,
                      cursorColor: AppColors.primaryPink,
                      decoration: InputDecoration(
                        labelText: 'email',
                        labelStyle: GoogleFonts.poppins(color: AppColors.primaryPink),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.4), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'choose avatar color',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: AppColors.categoryColors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            modalSetState(() {
                              tempAvatarColor = color;
                            });
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: color,
                            child: tempAvatarColor == color
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'choose avatar icon',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _fruitIcons.map((iconData) {
                        return GestureDetector(
                          onTap: () {
                            modalSetState(() {
                              tempAvatarIcon = iconData;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.surface,
                              child: Icon(
                                iconData,
                                size: 18,
                                color: tempAvatarIcon == iconData ? AppColors.primaryPink : theme.hintColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('cancel', style: GoogleFonts.poppins(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_currentUser != null) {
                              if (tempDisplayName != _currentUser!.displayName) {
                                await _currentUser!.updateDisplayName(tempDisplayName);
                              }
                            }
                            await widget.firestoreService.saveUserProfileData(
                              avatarColorValue: tempAvatarColor.value,
                              avatarIconCodePoint: tempAvatarIcon.codePoint,
                              email: tempEmail,
                              displayName: tempDisplayName,
                            );
                            setState(() {
                              _displayNameController.text = tempDisplayName;
                              _emailController.text = tempEmail;
                              _currentAvatarColor = tempAvatarColor;
                              _currentAvatarIcon = tempAvatarIcon;
                            });
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPink,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text('save changes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _CustomBirthdayPicker(
          initialDate: _birthday ?? DateTime.now(),
        );
      },
    );

    if (picked != null && picked != _birthday) {
      setState(() {
        _birthday = picked;
      });
      await widget.firestoreService.saveUserProfileData(birthday: picked);
      if (_displayNameController.text.isNotEmpty) {
        await notificationService.scheduleBirthdayNotification(
          context: context,
          userName: _displayNameController.text,
          birthDate: picked,
        );
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.softCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('log out?', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold)),
          content: Text('are you sure you want to log out?', style: GoogleFonts.poppins(color: AppColors.textDark)),
          actions: [
            TextButton(
              child: Text('cancel', style: GoogleFonts.poppins(color: AppColors.textDark)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPink,
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('log out'),
              onPressed: () {
                Navigator.of(context).pop();
                _logOut();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => WelcomeScreen(
            firestoreService: widget.firestoreService,
            onOnboardingComplete: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            showEmailVerificationPrompt: false,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }


  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.softCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text('delete account?', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold)),
          content: Text('this is a permanent action. all your data will be deleted.', style: GoogleFonts.poppins(color: AppColors.textDark)),
          actions: [
            TextButton(
              child: Text('cancel', style: GoogleFonts.poppins(color: AppColors.textDark)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                 textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await widget.firestoreService.deleteAllUserData();
      await user.delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('account deleted successfully.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(
              firestoreService: widget.firestoreService,
              onOnboardingComplete: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
              showEmailVerificationPrompt: false,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        if (e.code == 'requires-recent-login') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'this action requires a recent sign-in. please log out and log back in to delete your account.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('error deleting account: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('an unexpected error occurred: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          title: Text(
            'profile',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: isDarkMode ? AppColors.lightGrey : AppColors.textDark,
                ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryPink),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
                    _buildProfileCard(
                      title: 'user info',
                      content: Row(
                        children: [
                          GestureDetector(
                            onTap: _showEditProfileModal,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: _currentAvatarColor,
                              child: Icon(
                                _currentAvatarIcon,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayNameController.text.toLowerCase().isNotEmpty
                                      ? _displayNameController.text.toLowerCase()
                                      : (_currentUser?.displayName?.toLowerCase() ?? 'guest user'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (_emailController.text.isNotEmpty)
                                  Text(
                                    _emailController.text.toLowerCase(),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _selectBirthday(context),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.cake_outlined, color: AppColors.primaryPink, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _birthday == null
                                            ? 'add your birthday!'
                                            : DateFormat.yMMMMd().format(_birthday!).toLowerCase(),
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.primaryPink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<List<Task>>(
                      stream: widget.firestoreService.getTasks(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('error loading tasks: ${snapshot.error}', style: GoogleFonts.poppins(color: AppColors.errorRed));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primaryPink));
                        }

                        final allTasks = snapshot.data!;
                        final completedTasks = allTasks.where((task) => task.isCompleted).length;
                        final totalTasks = allTasks.length;
                        int longestStreak = 0;
                        if (allTasks.isNotEmpty) {
                          final completedDates = allTasks
                              .where((task) => task.isCompleted && task.dueDate != null)
                              .map((task) => DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day))
                              .toSet()
                              .toList()
                            ..sort();

                          if (completedDates.isNotEmpty) {
                            int currentStreak = 0;
                            for (int i = 0; i < completedDates.length; i++) {
                              if (i == 0) {
                                currentStreak = 1;
                              } else {
                                final diff = completedDates[i].difference(completedDates[i - 1]).inDays;
                                if (diff == 1) {
                                  currentStreak++;
                                } else if (diff > 1) {
                                  currentStreak = 1;
                                }
                              }
                              if (currentStreak > longestStreak) {
                                longestStreak = currentStreak;
                              }
                            }
                          }
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _checkAndUnlockBadges(totalTasks, completedTasks, longestStreak, allTasks);
                          }
                        });
                        String mostUsedCategory = 'n/a';
                        if (allTasks.isNotEmpty) {
                          final categoryCounts = <String, int>{};
                          for (var task in allTasks) {
                            categoryCounts[task.category] = (categoryCounts[task.category] ?? 0) + 1;
                          }
                          if (categoryCounts.isNotEmpty) {
                            mostUsedCategory = categoryCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                          }
                        }
                        return _buildProfileCard(
                          title: 'task statistics',
                          content: Column(
                            children: [
                              _buildStatRow(context, 'total tasks completed:', '$completedTasks / $totalTasks'),
                              _buildStatRow(context, 'longest streak:', '$longestStreak days'),
                              _buildStatRow(context, 'most used category:', mostUsedCategory.toLowerCase()),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildProfileCard(
                      title: 'achievement badges',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'earn badges for your productivity!',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              _buildBadge(
                                id: _firstTaskBadgeId,
                                text: 'first task done!',
                                icon: Icons.cake_rounded,
                                color: AppColors.accentYellow,
                                tagline: 'you\'ve completed your very first task!',
                              ),
                              _buildBadge(
                                id: _clockedInBadgeId,
                                text: 'clocked in',
                                icon: Icons.access_time_rounded,
                                color: AppColors.accentCoral,
                                tagline: 'your first scheduled task, right on time!',
                              ),
                              _buildBadge(
                                id: _strawberryStreakBadgeId,
                                text: 'strawberry streak',
                                icon: Icons.local_florist_rounded,
                                color: AppColors.primaryPink,
                                tagline: '7 days of getting things done — you’re on a roll!',
                              ),
                              _buildBadge(
                                id: _earlyRiserBadgeId,
                                text: 'early riser',
                                icon: Icons.wb_sunny_rounded,
                                color: AppColors.accentBlue,
                                tagline: 'you caught the sunrise and the productivity wave!',
                              ),
                              _buildBadge(
                                id: _categoryMasterBadgeId,
                                text: 'category master',
                                icon: Icons.folder_rounded,
                                color: AppColors.accentGreen,
                                tagline: 'your life’s officially organized into cute little boxes.',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildProfileCard(
                      title: 'account actions',
                      content: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface),
                            title: Text('log out', style: Theme.of(context).textTheme.bodyLarge),
                            onTap: _confirmLogout,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.delete_forever, color: AppColors.errorRed),
                            title: Text('delete account', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.errorRed)),
                            onTap: _confirmDeleteAccount,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
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

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.primaryPink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String id,
    required String text,
    required String tagline,
    required IconData icon,
    required Color color,
  }) {
    final bool isUnlocked = _unlockedBadgeIds.contains(id);
    final Color displayColor = isUnlocked ? color : Colors.grey;
    final Color textColor = isUnlocked ? color : Colors.grey.shade600;
    final Color backgroundColor = isUnlocked ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1);
    final Color borderColor = isUnlocked ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.5);

    return GestureDetector(
      onTap: () {
        _showBadgeDetailsDialog(
          text: text,
          tagline: tagline,
          icon: icon,
          color: color,
          isUnlocked: isUnlocked,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: displayColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// MODIFIED: Custom Birthday Picker Widget updated to remove text input feature
class _CustomBirthdayPicker extends StatefulWidget {
  final DateTime initialDate;

  const _CustomBirthdayPicker({required this.initialDate});

  @override
  _CustomBirthdayPickerState createState() => _CustomBirthdayPickerState();
}

class _CustomBirthdayPickerState extends State<_CustomBirthdayPicker> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  bool _isPickingYear = false;
  late ScrollController _yearScrollController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    // Calculate the initial offset to center the selected year
    final initialYearIndex = DateTime.now().year - _selectedDate.year;
    _yearScrollController = ScrollController(initialScrollOffset: initialYearIndex * 40.0);
  }
  
  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final dialogBackgroundColor = isDarkMode ? AppColors.darkBackground : AppColors.softCream;
    final textColor = isDarkMode ? AppColors.lightGrey : AppColors.textDark;
    const pinkColor = AppColors.primaryPink;

    return Dialog(
      backgroundColor: dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, pinkColor),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _isPickingYear
                  ? _buildYearPicker(textColor)
                  : _buildCalendar(theme, textColor, pinkColor),
            ),
            _buildActions(theme, pinkColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color pinkColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => setState(() => _isPickingYear = !_isPickingYear),
            child: Text(
              DateFormat('MMMM yyyy').format(_currentMonth).toLowerCase(),
              style: theme.textTheme.titleMedium?.copyWith(color: pinkColor, fontWeight: FontWeight.bold),
            ),
          ),
          if (!_isPickingYear)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: pinkColor),
                  onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: pinkColor),
                  onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildYearPicker(Color textColor) {
    final currentYear = DateTime.now().year;
    return SizedBox(
      height: 250,
      child: GridView.builder(
        controller: _yearScrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.6,
        ),
        itemCount: currentYear - 1900 + 1,
        itemBuilder: (context, index) {
          final year = currentYear - index;
          final isSelected = year == _currentMonth.year;
          return InkWell(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(year, _currentMonth.month);
                _isPickingYear = false;
              });
            },
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryPink.withOpacity(0.8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Text(
                  year.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Color textColor, Color pinkColor) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final weekdays = ['s', 'm', 't', 'w', 't', 'f', 's'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) => Text(day, style: theme.textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.7)))).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return Container();
              final day = index - firstWeekday + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isSelected = DateUtils.isSameDay(date, _selectedDate);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? pinkColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(color: isSelected ? Colors.white : textColor),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, Color pinkColor) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            child: Text('cancel', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('ok', style: TextStyle(color: pinkColor, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(context).pop(_selectedDate);
            },
          ),
        ],
      ),
    );
  }
}
