import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Helper class for Google Sign-In operations
/// Always shows account picker to ensure users can choose the correct account
class GoogleAuthHelper {
  /// Sign in with Google and return authentication data
  /// Returns null if user cancels or if sign-in fails
  ///
  /// Returns a Map containing:
  /// - idToken: Google ID token for backend verification
  /// - email: User's email address
  /// - name: User's display name
  /// - picture: User's profile picture URL
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // Uses Firebase-managed clientId from google-services.json (Android)
      );

      // Sign out first to ensure account picker shows every time
      await googleSignIn.signOut();
      debugPrint('🔐 GoogleAuthHelper: Starting Google Sign-In...');

      // Show account picker
      final account = await googleSignIn.signIn();

      if (account == null) {
        debugPrint('❌ GoogleAuthHelper: User canceled sign-in');
        return null;
      }

      debugPrint('✅ GoogleAuthHelper: Account selected: ${account.email}');

      // Get authentication tokens
      final auth = await account.authentication;

      if (auth.idToken == null) {
        debugPrint('❌ GoogleAuthHelper: Failed to obtain ID token');
        return null;
      }

      return {
        'idToken': auth.idToken!,
        'email': account.email,
        'name': account.displayName ?? '',
        'picture': account.photoUrl,
      };
    } catch (e) {
      debugPrint('❌ GoogleAuthHelper: Error during sign-in: $e');
      return null;
    }
  }
}
