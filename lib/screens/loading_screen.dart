import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _textController;
  late AnimationController _logoController;

  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titlePulseAnimation;
  
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Title animations
    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    _titlePulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
    ));

    // Text animations
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    // Logo animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    ));

    // Start animations with delays
    _startAnimations();
  }

  void _startAnimations() {
    // Logo appears first
    _logoController.forward();
    
    // Title appears after logo
    Future.delayed(const Duration(milliseconds: 600), () {
      _titleController.forward();
    });
    
    // Text follows shortly after
    Future.delayed(const Duration(milliseconds: 1000), () {
      _textController.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Widget _buildStrawberryLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/icon_bgless.png', // Replace with your actual logo path
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.softCream, AppColors.lightPeach],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _titleController,
            _textController,
            _logoController,
          ]),
          builder: (context, child) {
            return Stack(
              children: [
                // Floating hearts background
                ...List.generate(6, (index) => _buildFloatingHeart(index)),
                
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated strawberry logo
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _logoRotateAnimation.value * 0.1,
                              child: _buildStrawberryLogo(),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Animated title - all pink now
                      SlideTransition(
                        position: _titleSlideAnimation,
                        child: FadeTransition(
                          opacity: _titleFadeAnimation,
                          child: Transform.scale(
                            scale: _titlePulseAnimation.value,
                            child: Text(
                              'pinknote',
                              style: GoogleFonts.poppins(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryPink,
                                letterSpacing: -0.05,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Animated tagline with gentle slide
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textFadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: Text(
                              'a calm space to plan tasks, note thoughts, and embrace your day.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textDark,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingHeart(int index) {
    final delays = [0, 400, 800, 1200, 1600, 2000];
    final hearts = ['♡', '✧', '◦', '♡', '✨', '◦'];
    final sizes = [12.0, 10.0, 8.0, 14.0, 12.0, 9.0];
    final positions = [
      const Offset(0.15, 0.25),
      const Offset(0.85, 0.2),
      const Offset(0.1, 0.7),
      const Offset(0.9, 0.75),
      const Offset(0.2, 0.15),
      const Offset(0.8, 0.85),
    ];

    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final offset = (index * 200 + delays[index]) / 1000.0;
        final animValue = (_logoController.value + offset) % 1.0;
        final floatY = sin(animValue * 2 * pi + index) * 12;
        final opacity = (sin(animValue * pi + index * 0.5) * 0.25 + 0.35).clamp(0.0, 0.6);
        
        return Positioned(
          left: MediaQuery.of(context).size.width * positions[index].dx,
          top: MediaQuery.of(context).size.height * positions[index].dy + floatY,
          child: Opacity(
            opacity: opacity,
            child: Text(
              hearts[index],
              style: TextStyle(
                fontSize: sizes[index],
                color: AppColors.primaryPink.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }
}