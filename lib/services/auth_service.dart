import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// AuthService with Phone OTP and Google Sign-In (using google_sign_in package)
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '41887238104-28ibvegl19bo712v60678m9qj184sphc.apps.googleusercontent.com',
  );

  // ⚡ TEST MODE - Set to false when you have Twilio configured
  static const bool USE_TEST_MODE = true;
  static const String TEST_OTP = '123456';

  // ========================================
  // PHONE OTP AUTHENTICATION
  // ========================================

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    debugPrint('📱 Sending OTP to: $phoneNumber');

    if (USE_TEST_MODE) {
      debugPrint('🧪 TEST MODE: Use OTP: $TEST_OTP');
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    try {
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
      debugPrint('✅ OTP sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      return false;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOTP(String phone, String otp) async {
    debugPrint('🔍 Verifying OTP: $otp');

    if (USE_TEST_MODE) {
      debugPrint('🧪 TEST MODE ACTIVE');
      if (otp == TEST_OTP) {
        debugPrint('✅ OTP verified!');
        return true;
      } else {
        debugPrint('❌ Invalid OTP. Expected: $TEST_OTP');
        return false;
      }
    }

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      bool success = response.user != null;
      debugPrint(success ? '✅ OTP verified!' : '❌ Invalid OTP');
      return success;
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      return false;
    }
  }

  // ========================================
  // GOOGLE SIGN-IN (Native Package)
  // ========================================

  /// Sign in with Google (using native Google Sign-In)
  /// Set forceAccountSelection to true to always show account picker
  Future<bool> signInWithGoogle({bool forceAccountSelection = true}) async {
    debugPrint('🔵 Starting Google Sign-In...');

    try {
      // If forceAccountSelection is true, sign out first
      if (forceAccountSelection) {
        await _googleSignIn.signOut();
        debugPrint('🔄 Cleared previous session - showing account picker');
      }

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ User cancelled sign-in');
        return false;
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        debugPrint('❌ Failed to get access token');
        return false;
      }

      debugPrint('✅ Got access token');

      // Sign in to Supabase with Google credentials
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );

      if (response.user != null) {
        debugPrint('✅ Signed in to Supabase: ${response.user!.email}');
        return true;
      } else {
        debugPrint('❌ Failed to sign in to Supabase');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error with Google Sign-In: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  // ========================================
  // USER MANAGEMENT
  // ========================================

  /// Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    if (USE_TEST_MODE) {
      return 'test-user-123';
    }
    return _supabase.auth.currentUser?.id;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    if (USE_TEST_MODE) {
      return true;
    }
    return _supabase.auth.currentUser != null;
  }

  /// Sign out
  Future<void> signOut() async {
    debugPrint('👋 Signing out...');

    if (USE_TEST_MODE) {
      debugPrint('🧪 TEST MODE: Simulated sign out');
      return;
    }

    try {
      await _supabase.auth.signOut();
      await _googleSignIn.signOut(); // Also sign out from Google
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
