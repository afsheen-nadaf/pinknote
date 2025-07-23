import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user cancels the sign-in, return null
      if (googleUser == null) {
        debugPrint("Google Sign-In was cancelled by the user.");
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      debugPrint("Signing in to Firebase with Google credential...");
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint("Successfully signed in with Google: ${userCredential.user?.displayName}");
      return userCredential;

    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      debugPrint("FirebaseAuthException during Google Sign-In: ${e.message}");
      // You can add more specific error handling here based on e.code
      return null;
    } catch (e) {
      // Handle other errors
      debugPrint("An unexpected error occurred during Google Sign-In: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint("User signed out successfully.");
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}