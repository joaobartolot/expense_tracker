class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

class AuthCancelledException extends AuthException {
  const AuthCancelledException()
    : super('Google sign-in was cancelled before it completed.');
}

class AuthConfigurationException extends AuthException {
  const AuthConfigurationException(super.message);
}

class AuthFailureException extends AuthException {
  const AuthFailureException(super.message);
}
