import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Import shared_preferences

import '../utils/app_constants.dart';
import '../services/firestore_service.dart'; // Import FirestoreService
// Import WelcomeScreen

class InitialOnboardingScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final VoidCallback onOnboardingComplete; // This callback now handles navigation to WelcomeScreen

  const InitialOnboardingScreen({
    super.key,
    required this.firestoreService,
    required this.onOnboardingComplete,
  });

  Future<void> _completeInitialOnboarding(BuildContext context) async {
    // Call the callback to signal completion, which will trigger navigation in main.dart
    onOnboardingComplete();
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
            stops: [0.0, 1.0],
          ),
        ),
        // FIX: Center the content and constrain its width for better web layout.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(
                    'welcome to pinknote!',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // FIX: Updated the welcome text as per user request.
                  Text(
                    'a gentle and mindful space to jot your thoughts, organize your tasks, and embrace your day with calm.',
                    style: GoogleFonts.quicksand(
                      fontSize: 20,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _completeInitialOnboarding(context), // Pass context
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primaryPink.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'let\'s begin',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}