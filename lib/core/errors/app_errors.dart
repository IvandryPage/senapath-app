/// Base exception class for all application errors.
abstract class AppError implements Exception {
  /// Creates an application error with a descriptive message.
  const AppError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => message;
}

/// Error related to network operations and HTTP requests.
class NetworkError extends AppError {
  /// Creates a network error with optional status code.
  const NetworkError({
    required String message,
    this.statusCode,
    this.operation,
  }) : super(message);

  /// HTTP status code if available.
  final int? statusCode;

  /// Operation that failed (e.g., "fetch_sessions", "upload_telemetry").
  final String? operation;

  @override
  String toString() => statusCode != null
      ? 'NetworkError ($statusCode): $message'
      : 'NetworkError: $message';
}

/// Error related to authentication and authorization.
class AuthError extends AppError {
  /// Creates an authentication error with optional status code.
  const AuthError({
    required String message,
    this.statusCode,
    this.isUnauthorized = false,
  }) : super(message);

  /// HTTP status code if available.
  final int? statusCode;

  /// Whether this is an unauthorized (401) error requiring re-authentication.
  final bool isUnauthorized;

  @override
  String toString() => statusCode != null
      ? 'AuthError ($statusCode): $message'
      : 'AuthError: $message';
}

/// Error related to local storage operations.
class StorageError extends AppError {
  /// Creates a storage error with the failed operation name.
  const StorageError({
    required String message,
    required this.operation,
    this.key,
  }) : super(message);

  /// Operation that failed (e.g., "read", "write", "delete").
  final String operation;

  /// Storage key involved in the operation, if applicable.
  final String? key;

  @override
  String toString() => 'StorageError ($operation): $message';
}

/// Error related to data validation and parsing.
class ValidationError extends AppError {
  /// Creates a validation error with the field that failed validation.
  const ValidationError({
    required String message,
    this.field,
  }) : super(message);

  /// Field that failed validation, if applicable.
  final String? field;

  @override
  String toString() =>
      field != null ? 'ValidationError ($field): $message' : 'ValidationError: $message';
}

/// Error related to database operations.
class DatabaseError extends AppError {
  /// Creates a database error with the failed operation.
  const DatabaseError({
    required String message,
    this.operation,
    this.table,
  }) : super(message);

  /// Operation that failed (e.g., "insert", "update", "query").
  final String? operation;

  /// Table involved in the operation, if applicable.
  final String? table;

  @override
  String toString() => operation != null
      ? 'DatabaseError ($operation): $message'
      : 'DatabaseError: $message';
}

/// Error related to encryption and decryption operations.
class EncryptionError extends AppError {
  /// Creates an encryption error.
  const EncryptionError({
    required String message,
    this.operation,
  }) : super(message);

  /// Operation that failed (e.g., "encrypt", "decrypt", "key_generation").
  final String? operation;

  @override
  String toString() => operation != null
      ? 'EncryptionError ($operation): $message'
      : 'EncryptionError: $message';
}

/// Error related to cloud synchronization.
class SyncError extends AppError {
  /// Creates a sync error.
  const SyncError({
    required String message,
    this.operation,
    this.isRetryable = false,
  }) : super(message);

  /// Operation that failed (e.g., "push", "pull", "merge").
  final String? operation;

  /// Whether this error can be retried.
  final bool isRetryable;

  @override
  String toString() =>
      operation != null ? 'SyncError ($operation): $message' : 'SyncError: $message';
}

/// Error indicating a configuration problem.
class ConfigurationError extends AppError {
  /// Creates a configuration error.
  const ConfigurationError({
    required String message,
    this.configKey,
  }) : super(message);

  /// Configuration key that is missing or invalid.
  final String? configKey;

  @override
  String toString() => configKey != null
      ? 'ConfigurationError ($configKey): $message'
      : 'ConfigurationError: $message';
}

/// Error indicating a timeout occurred.
class TimeoutError extends AppError {
  /// Creates a timeout error with the operation that timed out.
  const TimeoutError({
    required String message,
    this.operation,
    this.duration,
  }) : super(message);

  /// Operation that timed out.
  final String? operation;

  /// Duration after which the timeout occurred.
  final Duration? duration;

  @override
  String toString() => operation != null
      ? 'TimeoutError ($operation): $message'
      : 'TimeoutError: $message';
}
