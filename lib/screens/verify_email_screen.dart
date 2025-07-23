import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';
// Assuming login_screen is in the same directory

class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback onVerified;

  const VerifyEmailScreen({super.key, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _canResendEmail = false;
  int _cooldownSeconds = 60;
  Timer? _resendCooldownTimer;

  @override
  void initState() {
    super.initState();
    // Start a timer to periodically check if the email has been verified
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
    // Start the initial cooldown for the resend button
    _startResendCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  /// Checks the verification status of the current user.
  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        _timer?.cancel();
        widget.onVerified(); // Navigate to the home page
      }
    }
  }

  /// Sends a new verification email.
  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _canResendEmail) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('a new verification email has been sent.'),
            backgroundColor: Colors.green,
          ),
        );
        _startResendCooldown(); // Restart the cooldown
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to send email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Starts the cooldown timer for the resend button.
  void _startResendCooldown() {
    setState(() {
      _canResendEmail = false;
      _cooldownSeconds = 60;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _canResendEmail = true;
        });
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  /// Signs the user out and returns to the welcome/login flow.
  Future<void> _cancelVerification() async {
    await FirebaseAuth.instance.signOut();
    // Navigate back to the root/welcome screen.
    // This assumes you have a way to reset the navigation stack.
    // For simplicity, we'll pop until we're at the root.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.softCream, AppColors.lightPeach],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 100,
                  color: AppColors.primaryPink,
                ),
                const SizedBox(height: 30),
                Text(
                  'verify your email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'we\'ve sent a verification link to:\n$userEmail',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '(please check your spam folder if you don\'t see it)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _canResendEmail ? _resendVerificationEmail : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.email_outlined, color: Colors.white),
                  label: Text(
                    _canResendEmail ? 'resend email' : 'resend in $_cooldownSeconds s',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelVerification,
                  child: Text(
                    'cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.textLight,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}