import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schedly/exceptions.dart';

class AuthenticationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Register a new user with Email and Password
  static Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Always send verification email on new registration
    if (userCredential.user != null && !userCredential.user!.emailVerified) {
      await userCredential.user!.sendEmailVerification();
    }

    return userCredential;
  }

  /// Sign in with Email and Password
  static Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Link an existing anonymous account with an Email and Password
  static Future<UserCredential> linkAnonymousAccount({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw AppException('No anonymous user is currently signed in.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final userCredential = await user.linkWithCredential(credential);

    if (userCredential.user != null && !userCredential.user!.emailVerified) {
      await userCredential.user!.sendEmailVerification();
    }

    // Mark the user document with the email for reference if needed
    await _db.collection('users').doc(user.uid).set({
      'email': email,
      'emailLinkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return userCredential;
  }

  /// Send a password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Resend verification email
  static Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Check if email is verified (forces token refresh)
  static Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload(); // Refresh the user token to get latest status
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
