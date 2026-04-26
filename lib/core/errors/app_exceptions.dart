/// Base exception class for NoteVault app
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when validation fails (invalid input)
class ValidationError extends AppException {
  const ValidationError(super.message);
}

/// Thrown when authentication fails
class AuthenticationError extends AppException {
  const AuthenticationError(super.message);
}

/// Thrown when encryption/decryption fails
class EncryptionError extends AppException {
  const EncryptionError(super.message);
}

/// Thrown when a vault operation fails
class VaultOperationError extends AppException {
  const VaultOperationError(super.message);
}

/// Thrown when a note operation fails
class NoteOperationError extends AppException {
  const NoteOperationError(super.message);
}

/// Thrown when local storage fails
class StorageError extends AppException {
  const StorageError(super.message);
}

/// Generic app error with no specific type
class AppError extends AppException {
  const AppError(super.message);
}
