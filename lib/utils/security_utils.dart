import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  // SHA-256 hash of the master password
  static const String _masterPasswordHash = '652f3d7b860776a2537a2c3a3b42702aed372a2b49c802b077470ad3efdf3f4d';

  static String get masterHash => _masterPasswordHash;

  /// Verifies if the provided plain text master password matches the hash.
  static bool verifyMasterPassword(String plainTextPassword) {
    final bytes = utf8.encode(plainTextPassword);
    final hash = sha256.convert(bytes).toString();
    return hash == _masterPasswordHash;
  }
}
