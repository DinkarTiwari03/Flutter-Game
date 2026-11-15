sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// A repository could not read or write data. Implementations wrap their
/// backend-specific errors (SQLite, Firebase, ...) in this type so game logic
/// never depends on a particular backend's exceptions.
final class RepositoryException extends AppException {
  const RepositoryException(super.message, {super.cause, super.stackTrace});
}

/// Input rejected by a service before anything was persisted.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.stackTrace});
}

final class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.cause, super.stackTrace});
}
