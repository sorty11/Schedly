import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart';
import '../exceptions.dart';
import 'notification_service.dart';
import 'topic_subscription_service.dart';
import '../onboarding/services/tutorial_storage_service.dart';

/// Result of an account deletion attempt.
class AccountDeletionResult {
  final bool success;
  final String message;
  final String? failedStep;
  final List<String> stepsCompleted;

  const AccountDeletionResult({
    required this.success,
    required this.message,
    this.failedStep,
    this.stepsCompleted = const [],
  });
}

class AccountDeletionService {
  static const String _defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://schedly-p61g.onrender.com',
  );

  /// Checks if the current user is authenticated via password.
  static bool get isPasswordUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Re-authenticates the current user with the provided password.
  /// Throws [AppException] if re-authentication fails.
  static Future<void> reauthenticate(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AppException('No user is currently signed in.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw AppException('User account has no associated email address.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AppException(
          'Incorrect password. Please verify and try again.',
          code: e.code,
        );
      } else if (e.code == 'user-mismatch') {
        throw AppException(
          'Credentials do not match the current account.',
          code: e.code,
        );
      } else if (e.code == 'user-not-found') {
        throw AppException('User account was not found.', code: e.code);
      } else {
        throw AppException(
          e.message ?? 'Re-authentication failed.',
          code: e.code,
        );
      }
    } catch (e) {
      throw AppException('Re-authentication error: $e');
    }
  }

  /// Executes the ordered account deletion workflow.
  ///
  /// 1. Re-authenticates if user is a password user.
  /// 2. Clears FCM topic subscriptions and device token registrations.
  /// 3. Obtains a fresh Firebase ID token.
  /// 4. Dispatches deletion request to the trusted Render backend running Admin SDK.
  /// 5. On backend confirmation, wipes local caches and signs out.
  ///
  /// Throws [AppException] if any step fails.
  static Future<AccountDeletionResult> deleteAccount({
    String? password,
    String? customBackendUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AppException('No authenticated user found to delete.');
    }

    // Step 1: Enforce re-authentication for password-based accounts
    if (isPasswordUser) {
      if (password == null || password.isEmpty) {
        throw AppException('Password is required to confirm account deletion.');
      }
      await reauthenticate(password);
    }

    // Step 2: Clear local notification topics & device tokens
    try {
      await TopicSubscriptionService.clearAllSubscriptions();
      await NotificationService.clearTokenOnLogout();
    } catch (e) {
      debugPrint(
        'AccountDeletionService: Local notification teardown warning: $e',
      );
      // Non-fatal, continue with deletion
    }

    // Step 3: Fetch fresh ID token
    String idToken;
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw AppException('Failed to obtain fresh authentication token.');
      }
      idToken = token;
    } catch (e) {
      throw AppException('Failed to refresh authentication token: $e');
    }

    // Step 4: Dispatch deletion request to trusted backend
    final baseUrl = customBackendUrl ?? _defaultBackendUrl;
    final endpoint = Uri.parse('$baseUrl/api/v1/delete-account');

    http.Response response;
    try {
      response = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw AppException(
        'Server took too long to respond. Your account data may be partially processed; please retry.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw AppException(
        'Unable to connect to deletion service. Please check your internet connection and try again: $e',
        code: 'NETWORK_ERROR',
      );
    }

    Map<String, dynamic> responseBody = {};
    try {
      responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode != 200) {
      final serverError =
          responseBody['error'] as String? ??
          'Deletion failed with status code ${response.statusCode}';
      final failedStep = responseBody['failedStep'] as String?;
      throw AppException(
        serverError,
        code: 'SERVER_ERROR',
        details: failedStep,
      );
    }

    // Step 5: Wipe local state and sign out
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await AppSettings.resetRole();
      AppSettings.studentName = null;
      AppSettings.studentRollNo = null;
      await TutorialStorageService.resetAll();
    } catch (e) {
      debugPrint('AccountDeletionService: Local state clear warning: $e');
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('AccountDeletionService: SignOut warning: $e');
    }

    final stepsCompleted = List<String>.from(
      responseBody['stepsCompleted'] ?? [],
    );
    return AccountDeletionResult(
      success: true,
      message: responseBody['message'] ?? 'Account deleted successfully.',
      stepsCompleted: stepsCompleted,
    );
  }
}
