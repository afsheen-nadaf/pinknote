// Import for ImageFilter
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pinknote/screens/home_screen.dart';
import 'package:pinknote/screens/tasks_screen.dart';
import 'package:pinknote/screens/pomodoro_screen.dart';
import 'package:pinknote/screens/calendar_screen.dart';
import 'package:pinknote/screens/profile_screen.dart';
import 'package:pinknote/screens/settings_screen.dart';
import 'package:pinknote/screens/mood_tracker_screen.dart';
import 'package:pinknote/screens/initial_onboarding_screen.dart';
import 'package:pinknote/screens/welcome_screen.dart';
import 'package:pinknote/screens/verify_email_screen.dart';
import 'package:pinknote/screens/loading_screen.dart'; // Import the LoadingScreen

import 'package:pinknote/services/services.dart';
import 'package:pinknote/utils/app_constants.dart';
import 'package:pinknote/models/category.dart';
import 'package:pinknote/models/event.dart';
import 'package:pinknote/theme_mode_notifier.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // REMOVED: Do not request permissions in main(). This can cause startup issues on iOS.
  // await Permission.notification.request();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _hasCompletedInitialOnboarding = false;
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialized");

      // Initialize FirestoreService AFTER Firebase is initialized
      _firestoreService = FirestoreService("pinknote_app");
      debugPrint("FirestoreService initialized");

      // MOVED: Request notification permission here.
      // It's better to ask for permission here than in main(), but ideally,
      // this should be triggered by a user action, e.g., a button in settings.
      // We check if the user has already denied the permission before requesting.
      if (await Permission.notification.isDenied) {
          await Permission.notification.request();
      }

      // 2. Load SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedInitialOnboarding = prefs.getBool('has_completed_initial_onboarding') ?? false;
      debugPrint('hasCompletedInitialOnboarding: $_hasCompletedInitialOnboarding');

      // 3. Initialize Notification Service
      await notificationService.init().timeout(const Duration(seconds: 5));
      debugPrint("Notification service initialized");
      notificationService.setNavigatorKey(navigatorKey);

      // Check if notifications are enabled before scheduling
      final status = await Permission.notification.status;
      if (status.isGranted) {
        await notificationService.scheduleDailyGoodMorningNotification(context).timeout(const Duration(seconds: 5));
        debugPrint("Scheduled good morning notification");
        await notificationService.scheduleDailyMoodReminderNotification(context).timeout(const Duration(seconds: 5));
        debugPrint("Scheduled daily mood reminder");
      } else {
        debugPrint("Notifications are not granted. Skipping daily notification scheduling.");
      }

      // 4. Load Sound Preference
      await soundService.loadSoundPreference().timeout(const Duration(seconds: 5));
      debugPrint("Sound prefs loaded");

      // Simulate a minimum loading time to ensure the loading screen is visible
      await Future.delayed(const Duration(seconds: 2));

    } catch (e) {
      debugPrint("App initialization error: $e");
      // Handle initialization errors (e.g., show an error message)
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeModeNotifier(),
      child: Consumer<ThemeModeNotifier>(
        builder: (context, themeModeNotifier, child) {
          ThemeMode currentThemeMode;
          switch (themeModeNotifier.themeMode) {
            case AppThemeMode.light:
              currentThemeMode = ThemeMode.light;
              break;
            case AppThemeMode.dark:
              currentThemeMode = ThemeMode.dark;
              break;
            case AppThemeMode.system:
              currentThemeMode = ThemeMode.system;
              break;
          }

          return MaterialApp(
            title: 'pinknote',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            themeMode: currentThemeMode,
            theme: ThemeData(
              primarySwatch: Colors.pink,
              scaffoldBackgroundColor: AppColors.lightPeach,
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: AppColors.primaryPink,
                selectionColor: AppColors.primaryPink,
                selectionHandleColor: AppColors.primaryPink,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryPink,
                brightness: Brightness.light,
                surface: AppColors.softCream,
                background: AppColors.lightPeach,
                onSurface: AppColors.textDark,
                onBackground: AppColors.textDark,
                outline: AppColors.borderLight,
                error: AppColors.errorRed,
              ),
              textTheme: TextTheme(
                displayLarge: GoogleFonts.poppins(fontSize: 50, color: AppColors.primaryPink, fontWeight: FontWeight.w700, letterSpacing: -1.5),
                headlineMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w600, fontSize: 20, letterSpacing: -0.5),
                bodyMedium: GoogleFonts.quicksand(fontSize: 16, height: 1.5, letterSpacing: 0.15, color: AppColors.textDark),
                displayMedium: GoogleFonts.poppins(fontSize: 40, color: AppColors.textDark, fontWeight: FontWeight.w600, letterSpacing: -1.0),
                displaySmall: GoogleFonts.poppins(fontSize: 30, color: AppColors.primaryPink, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                headlineSmall: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.25),
                titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                titleMedium: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: -0.25),
                titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
                bodyLarge: GoogleFonts.poppins(fontSize: 18, height: 1.6, letterSpacing: 0.15),
                bodySmall: GoogleFonts.poppins(fontSize: 14, height: 1.4, letterSpacing: 0.25),
                labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                labelMedium: GoogleFonts.poppins(fontSize: 12, letterSpacing: 0.5),
                labelSmall: GoogleFonts.poppins(fontSize: 10, letterSpacing: 0.5),
              ),
              appBarTheme: AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPink,
                  letterSpacing: -0.5,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: AppColors.softCream,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primaryPink,
                unselectedItemColor: Colors.black,
                elevation: 0,
              ),
              dividerColor: AppColors.borderLight,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.pink,
              scaffoldBackgroundColor: AppColors.darkBackground,
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: AppColors.primaryPink,
                selectionColor: AppColors.primaryPink,
                selectionHandleColor: AppColors.primaryPink,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryPink,
                brightness: Brightness.dark,
                surface: AppColors.darkSurface,
                background: AppColors.darkBackground,
                onSurface: AppColors.lightGrey,
                onBackground: AppColors.lightGrey,
                error: AppColors.errorRed,
                outline: AppColors.darkGrey,
              ),
              textTheme: TextTheme(
                displayLarge: GoogleFonts.poppins(fontSize: 50, color: AppColors.primaryPink, fontWeight: FontWeight.w700, letterSpacing: -1.5),
                headlineMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.lightGrey, letterSpacing: -0.5),
                bodyMedium: GoogleFonts.quicksand(fontSize: 16, height: 1.5, color: AppColors.lightGrey, letterSpacing: 0.15),
                displayMedium: GoogleFonts.poppins(fontSize: 40, color: AppColors.lightGrey, fontWeight: FontWeight.w600, letterSpacing: -1.0),
                displaySmall: GoogleFonts.poppins(fontSize: 30, color: AppColors.primaryPink, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                headlineSmall: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.lightGrey, letterSpacing: -0.25),
                titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.lightGrey, letterSpacing: -0.5),
                titleMedium: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.lightGrey, letterSpacing: -0.25),
                titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightGrey, letterSpacing: 0.1),
                bodyLarge: GoogleFonts.poppins(fontSize: 18, height: 1.6, color: AppColors.lightGrey, letterSpacing: 0.15),
                bodySmall: GoogleFonts.poppins(fontSize: 14, height: 1.4, color: AppColors.lightGrey, letterSpacing: 0.25),
                labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                labelMedium: GoogleFonts.poppins(fontSize: 12, color: AppColors.lightGrey, letterSpacing: 0.5),
                labelSmall: GoogleFonts.poppins(fontSize: 10, color: AppColors.lightGrey.withOpacity(0.8), letterSpacing: 0.5),
              ),
              appBarTheme: AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                backgroundColor: AppColors.darkGrey,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPink,
                  letterSpacing: -0.5,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: AppColors.darkSurface,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: AppColors.primaryPink,
                  foregroundColor: Colors.white,
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: AppColors.darkGrey,
                selectedItemColor: AppColors.primaryPink,
                unselectedItemColor: Colors.white,
                elevation: 0,
              ),
              dividerColor: AppColors.darkGrey,
              dialogBackgroundColor: AppColors.darkSurface,
              cupertinoOverrideTheme: const CupertinoThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: AppColors.darkSurface,
                primaryColor: AppColors.primaryPink,
                barBackgroundColor: AppColors.darkGrey,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(color: AppColors.lightGrey),
                  pickerTextStyle: TextStyle(color: AppColors.lightGrey),
                ),
              ),
            ),
            home: _isLoading
                ? const LoadingScreen()
                : AuthFlowHandler(
                    firestoreService: _firestoreService,
                    hasCompletedInitialOnboarding: _hasCompletedInitialOnboarding,
                  ),
            routes: {
              '/home': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                final initialIndex = args?['initialIndex'] as int? ?? 0;
                return MainAppScreen(
                  firestoreService: _firestoreService,
                  initialIndex: initialIndex,
                );
              },
            },
          );
        },
      ),
    );
  }
}

class AuthFlowHandler extends StatefulWidget {
  final FirestoreService firestoreService;
  final bool hasCompletedInitialOnboarding;

  const AuthFlowHandler({
    super.key,
    required this.firestoreService,
    required this.hasCompletedInitialOnboarding,
  });

  @override
  State<AuthFlowHandler> createState() => _AuthFlowHandlerState();
}

class _AuthFlowHandlerState extends State<AuthFlowHandler> {
  late bool _hasCompletedInitialOnboarding;

  @override
  void initState() {
    super.initState();
    _hasCompletedInitialOnboarding = widget.hasCompletedInitialOnboarding;

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        widget.firestoreService.setUserId(user.uid);
        debugPrint('FirestoreService userId set to: ${user.uid}');
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [AppColors.darkBackground, AppColors.darkGrey]
                      : [AppColors.softCream, AppColors.lightPeach],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primaryPink,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'loading your workspace...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? AppColors.lightGrey.withOpacity(0.7)
                            : AppColors.textDark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!_hasCompletedInitialOnboarding) {
          debugPrint('Navigating to InitialOnboardingScreen');
          return InitialOnboardingScreen(
            firestoreService: widget.firestoreService,
            onOnboardingComplete: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_completed_initial_onboarding', true);
              if (mounted) {
                setState(() {
                  _hasCompletedInitialOnboarding = true;
                });
              }
            },
          );
        }

        final User? user = snapshot.data;

        if (user != null) {
          if (user.emailVerified) {
            debugPrint('Email verified user authenticated. Navigating to MainAppScreen.');
            return MainAppScreen(firestoreService: widget.firestoreService);
          } else {
            debugPrint('User not verified. Navigating to VerifyEmailScreen.');
            return VerifyEmailScreen(
              onVerified: () {
                setState(() {});
              },
            );
          }
        }
        else {
          debugPrint('No user authenticated. Navigating to WelcomeScreen.');
          return WelcomeScreen(
            firestoreService: widget.firestoreService,
            showEmailVerificationPrompt: false,
            onOnboardingComplete: () {
              debugPrint('Auth flow complete. Navigating to MainAppScreen.');
              Navigator.of(context).pushReplacementNamed(
                '/home',
                arguments: {'initialIndex': 0},
              );
            },
          );
        }
      },
    );
  }
}


class MainAppScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final int initialIndex;

  const MainAppScreen({super.key, required this.firestoreService, this.initialIndex = 0});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> with TickerProviderStateMixin {
  List<Category> _availableCategories = [];
  List<Event> _allEvents = [];
  late int _selectedIndex;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _pageTitles = const [
    'pinknote',
    'tasks',
    'calendar',
    'pomodoro timer',
    'mood tracker',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    _listenToCategories();
    _listenToEvents();
  }

  @override
  void didUpdateWidget(covariant MainAppScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _listenToCategories() {
    widget.firestoreService.getCategories().listen((categories) {
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          if (categories.where((c) => c.name.toLowerCase() == 'general').isEmpty) {
            widget.firestoreService.addCategory(Category(id: 'general', name: 'general', colorValue: AppColors.primaryPink.value));
          } else {
            final generalCategory = categories.firstWhere((c) => c.name.toLowerCase() == 'general');
            if (generalCategory.colorValue != AppColors.primaryPink.value) {
              widget.firestoreService.updateCategory(generalCategory.copyWith(colorValue: AppColors.primaryPink.value));
            }
          }
        });
      }
    });
  }

  void _listenToEvents() {
    if (mounted) {
      widget.firestoreService.getEvents().listen((events) {
        setState(() {
          _allEvents = events;
        });
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final List<Widget> screens = [
      HomeScreen(firestoreService: widget.firestoreService),
      TasksScreen(
        firestoreService: widget.firestoreService,
        availableCategories: _availableCategories,
        onAddCategory: widget.firestoreService.addCategory,
        onUpdateCategory: widget.firestoreService.updateCategory,
        onDeleteCategory: widget.firestoreService.deleteCategory,
      ),
      CalendarScreen(
        firestoreService: widget.firestoreService,
        allEvents: _allEvents,
        onAddEvent: widget.firestoreService.addEvent,
        onUpdateEvent: widget.firestoreService.updateEvent,
        onDeleteEvent: widget.firestoreService.deleteEvent,
        availableCategories: _availableCategories,
        onAddCategory: widget.firestoreService.addCategory,
        onUpdateCategory: widget.firestoreService.updateCategory,
        onDeleteCategory: widget.firestoreService.deleteCategory,
      ),
      const PomodoroScreen(),
      MoodTrackerScreen(firestoreService: widget.firestoreService),
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            leading: IconButton(
              icon: Icon(Icons.person_rounded, color: theme.colorScheme.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      firestoreService: widget.firestoreService,
                      availableCategories: _availableCategories,
                    ),
                  ),
                );
              },
            ),
            title: Text(
              _pageTitles[_selectedIndex],
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPink,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.settings_rounded, color: theme.colorScheme.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(firestoreService: widget.firestoreService),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: Container(
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
          child: SafeArea(
            top: true,
            bottom: true,
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
        ),
        bottomNavigationBar:
            BottomNavigationBar(
          items: [
            _buildNavItem(Icons.home_rounded, 'home', 0),
            _buildNavItem(Icons.task_alt_rounded, 'tasks', 1),
            _buildNavItem(Icons.calendar_today_rounded, 'calendar', 2),
            _buildNavItem(Icons.timer_rounded, 'pomodoro', 3),
            _buildNavItem(Icons.sentiment_satisfied_alt_rounded, 'mood', 4),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryPink,
          unselectedItemColor: isDarkMode ? Colors.white : Colors.black,
          selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.5,
          ),
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 10,
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: isSelected ? 26 : 24,
          color: isSelected
              ? AppColors.primaryPink
              : theme.bottomNavigationBarTheme.unselectedItemColor,
        ),
      ),
      label: label,
    );
  }
}