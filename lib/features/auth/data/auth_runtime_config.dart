class AuthRuntimeConfig {
  const AuthRuntimeConfig._();

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static String? get resolvedGoogleServerClientId {
    final trimmed = googleServerClientId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
