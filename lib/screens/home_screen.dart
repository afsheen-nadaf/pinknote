// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../utils/app_constants.dart';
import '../services/firestore_service.dart';
import '../services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/daily_routines_modal.dart';

class FloatingElement {
  double x;
  double y;
  double size;
  double opacity;
  double speed;
  Color color;

  FloatingElement({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.color,
  });
}

class HomeScreen extends StatefulWidget {
  final FirestoreService firestoreService;

  const HomeScreen({
    super.key,
    required this.firestoreService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _greeting = '';
  List<InlineSpan> _sublineSpans = [];
  String? _weatherIconUrl;
  String _currentQuote = '';
  String _currentDate = '';
  String _currentTime = '';
  User? _currentUser;
  String _weatherCondition = 'loading...';
  String _temperature = '--°C';
  StreamSubscription? _profileSubscription;

  final WeatherService _weatherService = WeatherService();
  Timer? _timeTimer;

  final List<FloatingElement> _floatingElements = [];

  final List<String> _quotes = [
    "your small steps matter.",
    "one gentle task at a time.",
    "breathe in, breathe out, plan it out.",
    "today is a canvas, paint it well.",
    "progress, not perfection.",
    "you are capable of amazing things.",
  ];

  late AnimationController _greetingController;
  late Animation<Offset> _greetingSlideAnimation;
  late Animation<double> _greetingFadeAnimation;
  late AnimationController _weatherIconPulseController;
  late Animation<double> _weatherIconPulseAnimation;
  late AnimationController _quoteController;
  late Animation<double> _quoteFadeAnimation;
  late Animation<Offset> _quoteSlideAnimation;
  late Animation<double> _quoteScaleAnimation;
  late AnimationController _dateController;
  late Animation<Offset> _dateSlideAnimation;
  late Animation<double> _dateScaleAnimation;
  late AnimationController _weatherTextController;
  late Animation<Offset> _weatherTextSlideAnimation;
  late Animation<double> _weatherTextFadeAnimation;
  late AnimationController _weatherContainerController;
  late Animation<double> _weatherContainerScaleAnimation;
  late AnimationController _sublineController;
  late Animation<Offset> _sublineSlideAnimation;
  late Animation<double> _sublineFadeAnimation;
  late AnimationController _mainContentController;
  late Animation<Offset> _mainContentSlideAnimation;
  late Animation<double> _mainContentFadeAnimation;
  late AnimationController _floatingElementsController;
  late AnimationController _backgroundGradientController;
  late AnimationController _clockController;
  late Animation<double> _clockPulseAnimation;
  late AnimationController _weatherAnimationController;
  late Animation<double> _rainDropAnimation;
  late Animation<double> _sparkleAnimation;
  late AnimationController _routinesWidgetController;
  late Animation<double> _routinesWidgetFadeAnimation;
  late Animation<Offset> _routinesWidgetSlideAnimation;


  Future<void> _fetchRealWeather() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _temperature = '--°C';
        _weatherCondition = 'location disabled';
        _weatherIconUrl = null;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _temperature = '--°C';
          _weatherCondition = 'location denied';
          _weatherIconUrl = null;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _temperature = '--°C';
        _weatherCondition = 'location permanently denied';
        _weatherIconUrl = null;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final weatherData = await _weatherService.fetchWeather(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _temperature = '${weatherData['main']['temp'].round()}°C';
        _weatherCondition = weatherData['weather'][0]['description'];
        final iconCode = weatherData['weather'][0]['icon'];
        _weatherIconUrl = 'https://openweathermap.org/img/wn/$iconCode@4x.png';
      });
      _weatherTextController.forward(from: 0.0);
      _weatherContainerController.forward(from: 0.0);
      _startWeatherAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _temperature = '--°C';
        _weatherCondition = 'failed to load';
        _weatherIconUrl = null;
      });
    }
  }

  void _startWeatherAnimation() {
    _weatherAnimationController.reset();
    if (_weatherCondition.toLowerCase().contains('rain') || _weatherCondition.toLowerCase().contains('drizzle')) {
      _rainDropAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _weatherAnimationController, curve: Curves.linear),
      );
      _weatherAnimationController.repeat(period: const Duration(seconds: 2));
    } else if (_weatherCondition.toLowerCase().contains('clear') || _weatherCondition.toLowerCase().contains('sun')) {
      _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _weatherAnimationController, curve: Curves.easeInOut),
      );
      _weatherAnimationController.repeat(period: const Duration(seconds: 3));
    }
  }

  void _initializeFloatingElements() {
    final random = Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    _floatingElements.clear();

    final hour = DateTime.now().hour;
    List<Color> elementColors;

    if (isDarkMode) {
      elementColors = [
        AppColors.primaryPink.withOpacity(0.3),
        Colors.indigo.withOpacity(0.4),
        AppColors.lightGrey.withOpacity(0.2),
      ];
    } else {
      if (hour >= 5 && hour < 12) {
        elementColors = [
          AppColors.primaryPink.withOpacity(0.3),
          AppColors.lightPeach.withOpacity(0.4),
          AppColors.softCream.withOpacity(0.5),
        ];
      } else if (hour >= 12 && hour < 17) {
        elementColors = [
          AppColors.primaryPink.withOpacity(0.4),
          Colors.amber.withOpacity(0.3),
          AppColors.lightPeach.withOpacity(0.3),
        ];
      } else {
        elementColors = [
          AppColors.primaryPink.withOpacity(0.5),
          Colors.deepPurple.withOpacity(0.2),
          AppColors.softCream.withOpacity(0.4),
        ];
      }
    }

    for (int i = 0; i < 12; i++) {
      _floatingElements.add(
        FloatingElement(
          x: random.nextDouble() * screenWidth,
          y: random.nextDouble() * screenHeight,
          size: random.nextDouble() * 8 + 4,
          opacity: random.nextDouble() * 0.6 + 0.2,
          speed: random.nextDouble() * 0.5 + 0.1,
          color: elementColors[random.nextInt(elementColors.length)],
        ),
      );
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      int hour = now.hour;
      final String ampm = hour < 12 ? 'am' : 'pm';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final String minute = now.minute.toString().padLeft(2, '0');
      setState(() {
        _currentTime = "$hour:$minute $ampm";
      });
    }
  }

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _listenToProfile();
      }
    });

    _mainContentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _mainContentSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _mainContentController, curve: Curves.easeOutCubic));
    _mainContentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _mainContentController, curve: Curves.easeIn));
    _greetingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _greetingSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _greetingController, curve: Curves.easeOutBack));
    _greetingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _greetingController, curve: Curves.easeInOut));
    _sublineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _sublineSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _sublineController, curve: Curves.easeOutCubic));
    _sublineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _sublineController, curve: Curves.easeIn));
    _weatherIconPulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _weatherIconPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _weatherIconPulseController, curve: Curves.easeInOut));
    _weatherContainerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _weatherContainerScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _weatherContainerController, curve: Curves.easeOutBack));
    _quoteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _quoteFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _quoteController, curve: Curves.easeInOut));
    _quoteSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _quoteController, curve: Curves.easeOutCubic));
    _quoteScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _quoteController, curve: Curves.easeOut));
    _dateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _dateSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(CurvedAnimation(parent: _dateController, curve: Curves.easeOutBack));
    _dateScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _dateController, curve: Curves.easeOutBack));
    _weatherTextController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _weatherTextSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _weatherTextController, curve: Curves.easeOutCubic));
    _weatherTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _weatherTextController, curve: Curves.easeIn));
    _floatingElementsController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _backgroundGradientController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _clockController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _clockPulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _clockController, curve: Curves.easeInOut));
    _weatherAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _routinesWidgetController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _routinesWidgetFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _routinesWidgetController, curve: Curves.easeIn));
    _routinesWidgetSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _routinesWidgetController, curve: Curves.easeOutCubic));


    _setRandomQuote();
    _setCurrentDate();
    _updateTime();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeFloatingElements();
        setState(() {});
      }
    });

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());

    Future.delayed(const Duration(milliseconds: 100), () { if (mounted) _mainContentController.forward(); });
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _greetingController.forward(); });
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _sublineController.forward(); });
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _weatherContainerController.forward(); });
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) _dateController.forward(); });
    Future.delayed(const Duration(milliseconds: 900), () { if (mounted) _quoteController.forward(); });
    Future.delayed(const Duration(milliseconds: 1100), () { if (mounted) _weatherTextController.forward(); });
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) _routinesWidgetController.forward(); });

    _fetchRealWeather();
  }

  void _listenToProfile() {
    _profileSubscription?.cancel();
    if (_currentUser != null) {
      _profileSubscription = widget.firestoreService.getUserProfileStream().listen((profileData) {
        if (mounted) {
          final displayName = profileData['displayName'] as String? ?? _currentUser?.displayName;
          _setGreetingAndSubline(displayName);
        }
      });
    } else {
      _setGreetingAndSubline(null);
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _profileSubscription?.cancel();
    _greetingController.dispose();
    _sublineController.dispose();
    _weatherIconPulseController.dispose();
    _weatherContainerController.dispose();
    _quoteController.dispose();
    _dateController.dispose();
    _weatherTextController.dispose();
    _mainContentController.dispose();
    _floatingElementsController.dispose();
    _backgroundGradientController.dispose();
    _clockController.dispose();
    _weatherAnimationController.dispose();
    _routinesWidgetController.dispose();
    super.dispose();
  }

  void _setGreetingAndSubline(String? name) {
    final hour = DateTime.now().hour;
    String userName = name?.split(' ')[0].toLowerCase() ?? 'sunshine';
    String sublineText;

    if (hour >= 5 && hour < 12) {
      _greeting = "good morning, $userName";
      sublineText = "rise and shine, it's a brand new day";
    } else if (hour >= 12 && hour < 17) {
      _greeting = "hey there, $userName";
      sublineText = "hope your day's going sweet";
    } else if (hour >= 17 && hour < 21) {
      _greeting = "evening, $userName";
      sublineText = "unwind time. let's tie up the day with a little grace";
    } else {
      _greeting = "hi night owl, $userName";
      sublineText = "you made it through today — so proud of you";
    }

    setState(() {
      _sublineSpans = [
        TextSpan(text: '$sublineText '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.only(left: 4, right: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryPink.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              _getGreetingIconPath(hour),
              height: 16.0,
              width: 16.0,
              colorFilter: const ColorFilter.mode(AppColors.primaryPink, BlendMode.srcIn),
            ),
          ),
        ),
      ];
    });
  }

  String _getGreetingIconPath(int hour) {
    if (hour >= 5 && hour < 12) return 'assets/icons8-flower-24.svg';
    if (hour >= 12 && hour < 17) return 'assets/icons8-strawberry-48.svg';
    if (hour >= 17 && hour < 21) return 'assets/icons8-star-26.svg';
    return 'assets/icons8-stitched-heart-50.svg';
  }

  void _setRandomQuote() {
    if (mounted) {
      setState(() {
        _currentQuote = _quotes[Random().nextInt(_quotes.length)];
      });
      _quoteController.forward(from: 0.0);
    }
  }

  void _setCurrentDate() {
    final now = DateTime.now();
    _currentDate = "${AppConstants.weekdays[now.weekday - 1]}, ${AppConstants.months[now.month - 1]} ${now.day}";
  }

  Widget _buildFloatingElements() {
    return AnimatedBuilder(
      animation: _floatingElementsController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        return Stack(
          children: _floatingElements.map((element) {
            final animationValue = _floatingElementsController.value;
            final yOffset = (element.y + animationValue * element.speed * 100) % (screenHeight + element.size);
            final opacity = (sin(animationValue * 2 * pi + element.x / screenWidth * pi) + 1) / 2 * element.opacity;
            return Positioned(
              left: element.x,
              top: yOffset - element.size,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: animationValue * 2 * pi,
                  child: Container(
                    width: element.size,
                    height: element.size,
                    decoration: BoxDecoration(
                      color: element.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: element.color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAnimatedWeatherIcon() {
    final theme = Theme.of(context);
    final iconBackgroundColor = theme.colorScheme.primary.withOpacity(0.1);
    final iconBorderColor = theme.colorScheme.primary.withOpacity(0.2);
    final iconShadowColor = theme.colorScheme.primary.withOpacity(0.7);

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _weatherIconPulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorderColor, width: 1),
              boxShadow: [BoxShadow(color: iconShadowColor, blurRadius: 20, spreadRadius: 2)],
            ),
            child: _weatherIconUrl != null
                ? Image.network(
                    _weatherIconUrl!,
                    width: 80.0,
                    height: 80.0,
                    errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
                      'assets/icons8-cloud-error-50.svg',
                      height: 60.0,
                      width: 60.0,
                      colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn),
                    ),
                  )
                : SvgPicture.asset(
                    'assets/icons8-cloud-error-50.svg',
                    height: 60.0,
                    width: 60.0,
                    colorFilter: ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn),
                  ),
          ),
        ),
        if (_weatherCondition.toLowerCase().contains('rain') || _weatherCondition.toLowerCase().contains('drizzle')) ..._buildRainDrops(),
        if (_weatherCondition.toLowerCase().contains('clear') || _weatherCondition.toLowerCase().contains('sun')) ..._buildSparkles(),
      ],
    );
  }

  List<Widget> _buildRainDrops() {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: _weatherAnimationController,
        builder: (context, child) {
          final offset = (_weatherAnimationController.value + index * 0.3) % 1.0;
          return Positioned(
            top: 10 + offset * 60,
            left: 20 + index * 8.0,
            child: Opacity(
              opacity: 1.0 - offset,
              child: Container(
                width: 2,
                height: 8,
                decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.6), borderRadius: BorderRadius.circular(1)),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildSparkles() {
    return List.generate(4, (index) {
      return AnimatedBuilder(
        animation: _weatherAnimationController,
        builder: (context, child) {
          final sparkleValue = (_weatherAnimationController.value + index * 0.25) % 1.0;
          final opacity = (sin(sparkleValue * 2 * pi) + 1) / 2;
          final scale = 0.5 + opacity * 0.5;
          return Positioned(
            top: 5 + index * 12.0,
            left: 35 + (index % 2) * 15.0,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildDateTimeWidget() {
    final theme = Theme.of(context);
    return SlideTransition(
      position: _dateSlideAnimation,
      child: ScaleTransition(
        scale: _dateScaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
            boxShadow: [BoxShadow(color: AppColors.shadowSoft.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentDate,
                style: GoogleFonts.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                _currentTime,
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRoutinesWidget(ThemeData theme) {
    return FadeTransition(
      opacity: _routinesWidgetFadeAnimation,
      child: SlideTransition(
        position: _routinesWidgetSlideAnimation,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => DailyRoutinesModal(firestoreService: widget.firestoreService),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
              boxShadow: [BoxShadow(color: AppColors.shadowSoft.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.watch_later_outlined, color: AppColors.primaryPink, size: 32),
                const SizedBox(height: 8),
                Text(
                  "routines",
                  style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildFloatingElements(),
          SafeArea(
            child: FadeTransition(
              opacity: _mainContentFadeAnimation,
              child: SlideTransition(
                position: _mainContentSlideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: screenHeight * 0.02),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDateTimeWidget(),
                                  _buildDailyRoutinesWidget(theme),
                                ],
                              ),
                              ScaleTransition(
                                scale: _weatherContainerScaleAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1),
                                    boxShadow: [BoxShadow(color: AppColors.shadowSoft.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildAnimatedWeatherIcon(),
                                      const SizedBox(height: 16),
                                      FadeTransition(
                                        opacity: _weatherTextFadeAnimation,
                                        child: SlideTransition(
                                          position: _weatherTextSlideAnimation,
                                          child: Text(
                                            '$_temperature\n$_weatherCondition',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: screenHeight * 0.04),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeTransition(
                                opacity: _greetingFadeAnimation,
                                child: SlideTransition(
                                  position: _greetingSlideAnimation,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    child: Text(_greeting, style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.primaryPink, letterSpacing: -0.5, height: 1.2)),
                                  ),
                                ),
                              ),
                              FadeTransition(
                                opacity: _sublineFadeAnimation,
                                child: SlideTransition(
                                  position: _sublineSlideAnimation,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontFamily: 'Quicksand',
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                        children: _sublineSpans,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _setRandomQuote,
                                child: FadeTransition(
                                  opacity: _quoteFadeAnimation,
                                  child: SlideTransition(
                                    position: _quoteSlideAnimation,
                                    child: ScaleTransition(
                                      scale: _quoteScaleAnimation,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                                        decoration: BoxDecoration(
                                          color: theme.cardColor.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1),
                                          boxShadow: [BoxShadow(color: AppColors.shadowSoft.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                                       ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 24,
                                              decoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.6), borderRadius: BorderRadius.circular(2)),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                _currentQuote,
                                                style: GoogleFonts.quicksand(
                                                  fontSize: isSmallScreen ? 13 : 15,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3,
                                                  height: 1.3,
                                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}