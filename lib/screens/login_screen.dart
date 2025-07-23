import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_constants.dart';
import '../services/firestore_service.dart';
import 'verify_email_screen.dart'; // Import the new screen

class LoginScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.firestoreService,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          await user.reload();
          if (user.emailVerified) {
            debugPrint("user logged in: ${user.email}");
            widget.onLoginSuccess();
          } else {
            // User is not verified, navigate to the verification screen
            debugPrint("login failed: email not verified for ${user.email}");
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => VerifyEmailScreen(
                  onVerified: widget.onLoginSuccess,
                ),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            _errorMessage = 'no account found with these credentials.';
          } else if (e.code == 'wrong-password') {
            _errorMessage = 'wrong password provided for that user.';
          } else if (e.code == 'invalid-email') {
            _errorMessage = 'the email address is not valid.';
          } else if (e.code == 'user-disabled') {
            _errorMessage = 'this account has been disabled.';
          } else {
            _errorMessage = 'failed to log in: ${e.message}';
          }
        });
        debugPrint("firebase auth error: ${e.code} - ${e.message}");
      } catch (e) {
        setState(() {
          _errorMessage = 'an unexpected error occurred: $e';
        });
        debugPrint("general error: $e");
      } finally {
        if (mounted) {
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

      // We can save data here as well to ensure profile is up-to-date
      await widget.firestoreService.saveUserProfileData(
        email: userCredential.user?.email,
        displayName: userCredential.user?.displayName,
      );

      debugPrint(
          "user signed in with google: ${userCredential.user?.email}, name: ${userCredential.user?.displayName}");

      if (userCredential.user != null) {
        widget.onLoginSuccess(); // Navigate to MainAppScreen
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

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('password reset email sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'no user found for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'the email address is not valid.';
      } else {
        message = 'failed to send reset email: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint("firebase auth error: ${e.code} - ${e.message}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('an unexpected error occurred'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint("general error: $e");
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ResetPasswordDialog(
          onSend: (email) {
            _resetPassword(email);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryPink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                padding: EdgeInsets.fromLTRB(24.0,
                    24.0 + topPadding + AppBar().preferredSize.height, 24.0, 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'welcome back!',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'log in to your account.',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
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
                              hintText: 'your password',
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
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                              color: AppColors.errorRed, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _login,
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
                          : const Icon(Icons.login_rounded,
                              color: Colors.white, size: 24),
                      label: Text(
                        _isLoading ? 'logging in...' : 'log in',
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
                        _isLoading ? 'signing in...' : 'sign in with google',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        'forgot password?',
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

class _ResetPasswordDialog extends StatefulWidget {
  final Function(String) onSend;

  const _ResetPasswordDialog({required this.onSend});

  @override
  __ResetPasswordDialogState createState() => __ResetPasswordDialogState();
}

class __ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isButtonDisabled = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _isButtonDisabled = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        setState(() {
          _isButtonDisabled = false;
          _countdown = 60;
        });
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _handleSend() {
    if (_formKey.currentState!.validate()) {
      widget.onSend(_emailController.text.trim());
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.softCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Text('reset password', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(color: AppColors.textDark),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_rounded, color: AppColors.primaryPink),
            hintText: 'enter your email',
            hintStyle: GoogleFonts.poppins(color: AppColors.textLight.withOpacity(0.6)),
            filled: true,
            fillColor: AppColors.softCream,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.errorRed, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
            errorMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || !EmailValidator.validate(value.trim())) {
              return 'please enter a valid email address';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('cancel', style: GoogleFonts.poppins(color: AppColors.textDark)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryPink,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: _isButtonDisabled ? null : _handleSend,
          child: Text(
            _isButtonDisabled ? 'resend in $_countdown s' : 'send reset email',
          ),
        ),
      ],
    );
  }
}