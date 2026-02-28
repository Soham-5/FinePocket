import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Back to the required v7 instance!
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ==========================================
  // 1. GOOGLE SIGN IN
  // ==========================================
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 🚨 THE FIX: Pass your Web Client ID here inside initialize()
      await _googleSignIn.initialize(
        serverClientId: "114481393624-virqn0k49ifab2mjtotik2geedgmdrt8.apps.googleusercontent.com",
      );
      
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("🔴 Error signing in with Google: $e");
      return null;
    }
  }

  // ==========================================
  // 2. ANONYMOUS SIGN IN (Guest Mode)
  // ==========================================
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint("🔴 Error signing in anonymously: $e");
      return null;
    }
  }

  // ==========================================
  // 3. PHONE SIGN IN (Step 1: Send SMS)
  // ==========================================
  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification failed");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // ==========================================
  // 4. PHONE SIGN IN (Step 2: Verify SMS Code)
  // ==========================================
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("🔴 Error verifying OTP: $e");
      return null;
    }
  }

  // ==========================================
  // SIGN OUT
  // ==========================================
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("🔴 Error signing out: $e");
    }
  }
}