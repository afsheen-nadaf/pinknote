import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_constants.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart'; // Import the new screen

class WelcomeScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final VoidCallback onOnboardingComplete;

  const WelcomeScreen({
    super.key,
    required this.firestoreService,
    required this.onOnboardingComplete,
    required bool showEmailVerificationPrompt,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_nameController.text.trim());
          await user.sendEmailVerification();

          await widget.firestoreService.saveUserProfileData(
            email: user.email,
            displayName: _nameController.text.trim(),
          );

          debugPrint(
              "user created: ${user.email}, name: ${_nameController.text.trim()}");

          // Navigate to the verification screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(
                onVerified: widget.onOnboardingComplete,
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'weak-password') {
            _errorMessage = 'the password provided is too weak.';
          } else if (e.code == 'email-already-in-use') {
            _errorMessage = 'an account already exists for that email.';
          } else {
            _errorMessage = 'failed to create account: ${e.message}';
          }
        });
        debugPrint("firebase auth error: ${e.code} - ${e.message}");
      } catch (e) {
        setState(() {
          _errorMessage = 'an unexpected error occurred: $e';
        });
        debugPrint("general error: $e");
      } finally {
        // Don't set isLoading to false here if navigation is successful
        // to avoid a flicker on the welcome screen.
        if (mounted && _errorMessage != null) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      // This will force the account picker to show every time.
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await widget.firestoreService.saveUserProfileData(
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
      );

      debugPrint(
          "user signed in with google: ${userCredential.user?.email}, name: ${userCredential.user?.displayName}");

      if (userCredential.user != null) {
        widget.onOnboardingComplete(); // Navigate to MainAppScreen
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'google sign-in failed: ${e.message}';
      });
      debugPrint("firebase auth google error: ${e.code} - ${e.message}");
    } catch (e) {
      setState(() {
        _errorMessage =
            'an unexpected error occurred during google sign-in: $e';
      });
      debugPrint("general google sign-in error: $e");
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
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - keyboardHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'welcome to pinknote!',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'create your account to get started.',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                              color: AppColors.errorRed, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.text,
                            style: GoogleFonts.poppins(
                                fontSize: 18, color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'your name',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.primaryPink),
                              hintText: 'john doe',
                              hintStyle: GoogleFonts.poppins(
                                  color: AppColors.textLight.withOpacity(0.6)),
                              filled: true,
                              fillColor: AppColors.softCream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.person_rounded,
                                  color: AppColors.primaryPink),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'name cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.poppins(
                                fontSize: 18, color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'email address',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.primaryPink),
                              hintText: 'hello@example.com',
                              hintStyle: GoogleFonts.poppins(
                                  color: AppColors.textLight.withOpacity(0.6)),
                              filled: true,
                              fillColor: AppColors.softCream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.email_rounded,
                                  color: AppColors.primaryPink),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'email cannot be empty';
                              }
                              if (!EmailValidator.validate(value.trim())) {
                                return 'please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: GoogleFonts.poppins(
                                fontSize: 18, color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'password',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.primaryPink),
                              hintText: 'at least 6 characters',
                              hintStyle: GoogleFonts.poppins(
                                  color: AppColors.textLight.withOpacity(0.6)),
                              filled: true,
                              fillColor: AppColors.softCream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.lock_rounded,
                                  color: AppColors.primaryPink),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppColors.textLight,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'password cannot be empty';
                              }
                              if (value.trim().length < 6) {
                                return 'password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            style: GoogleFonts.poppins(
                                fontSize: 18, color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'confirm password',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.primaryPink),
                              hintText: 're-enter your password',
                              hintStyle: GoogleFonts.poppins(
                                  color: AppColors.textLight.withOpacity(0.6)),
                              filled: true,
                              fillColor: AppColors.softCream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.lock_rounded,
                                  color: AppColors.primaryPink),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppColors.textLight,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'confirm password cannot be empty';
                              }
                              if (value.trim() !=
                                  _passwordController.text.trim()) {
                                return 'passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 10,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded,
                              color: Colors.white, size: 24),
                      label: Text(
                        _isLoading ? 'creating account...' : 'create account',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.googleBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 10,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : SvgPicture.asset(
                              'assets/google_logo.svg',
                              height: 24,
                              width: 24,
                            ),
                      label: Text(
                        _isLoading ? 'signing up...' : 'sign up with google',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(
                            firestoreService: widget.firestoreService,
                            onLoginSuccess: widget.onOnboardingComplete,
                          ),
                        ),
                      ),
                      child: Text(
                        'already have an account? login',
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
        ),
      ),
    );
  }
}