import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class SecurityService {
  // Generate a random salt
  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  // Hash password with salt using SHA-256
  static String hashPassword(String password, {String? salt}) {
    salt ??= generateSalt();
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  // Verify password against stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;
      final salt = parts[0];
      final hash = hashPassword(password, salt: salt);
      return hash == storedHash;
    } catch (e) {
      return false;
    }
  }

  // Simple hash for non-security purposes (like audit IDs)
  static String simpleHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
