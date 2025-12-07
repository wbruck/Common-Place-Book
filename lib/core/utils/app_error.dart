/// Base class for application errors.
/// Provides structured error handling with user-friendly messages.
sealed class AppError {
  final String message;
  final String? debugInfo;
  final Object? originalError;

  const AppError({
    required this.message,
    this.debugInfo,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Database-related errors
class DatabaseError extends AppError {
  const DatabaseError({
    required super.message,
    super.debugInfo,
    super.originalError,
  });

  factory DatabaseError.readFailed({Object? error}) => DatabaseError(
        message: 'Failed to read data',
        debugInfo: 'Database read operation failed',
        originalError: error,
      );

  factory DatabaseError.writeFailed({Object? error}) => DatabaseError(
        message: 'Failed to save data',
        debugInfo: 'Database write operation failed',
        originalError: error,
      );

  factory DatabaseError.deleteFailed({Object? error}) => DatabaseError(
        message: 'Failed to delete data',
        debugInfo: 'Database delete operation failed',
        originalError: error,
      );

  factory DatabaseError.notFound(String entity) => DatabaseError(
        message: '$entity not found',
        debugInfo: 'Entity not found in database: $entity',
      );
}

/// Validation errors
class ValidationError extends AppError {
  final String field;

  const ValidationError({
    required super.message,
    required this.field,
    super.debugInfo,
  });

  factory ValidationError.empty(String field) => ValidationError(
        message: '$field is required',
        field: field,
        debugInfo: 'Validation failed: $field is empty',
      );

  factory ValidationError.tooLong(String field, int maxLength) => ValidationError(
        message: '$field must be less than $maxLength characters',
        field: field,
        debugInfo: 'Validation failed: $field exceeds max length of $maxLength',
      );

  factory ValidationError.invalid(String field, String reason) => ValidationError(
        message: '$field is invalid: $reason',
        field: field,
        debugInfo: 'Validation failed: $field - $reason',
      );
}

/// Network-related errors (for future cloud sync)
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    super.debugInfo,
    super.originalError,
  });

  factory NetworkError.noConnection() => const NetworkError(
        message: 'No internet connection',
        debugInfo: 'Network request failed: no connectivity',
      );

  factory NetworkError.timeout() => const NetworkError(
        message: 'Request timed out',
        debugInfo: 'Network request timed out',
      );

  factory NetworkError.serverError({Object? error}) => NetworkError(
        message: 'Server error occurred',
        debugInfo: 'Server returned an error',
        originalError: error,
      );
}

/// Unknown/unexpected errors
class UnknownError extends AppError {
  const UnknownError({
    super.message = 'An unexpected error occurred',
    super.debugInfo,
    super.originalError,
  });

  factory UnknownError.from(Object error) => UnknownError(
        message: 'An unexpected error occurred',
        debugInfo: error.toString(),
        originalError: error,
      );
}
