class LinkedEntityException implements Exception {
  const LinkedEntityException(this.message);

  final String message;

  @override
  String toString() => 'LinkedEntityException: $message';
}
