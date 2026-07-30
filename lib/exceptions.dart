class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) return '[$code] $message';
    return message;
  }
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code});
}

class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code});
}
