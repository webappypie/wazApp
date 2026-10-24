// lib/core/error/app_error.dart
//
// Typed error hierarchy for WazApp (docs/SYSTEM_ARCHITECTURE.md "Performance and errors").
// Raw exceptions are caught at the data/service boundary and converted before
// they reach the UI, so screens can show an actionable message.

import 'package:equatable/equatable.dart';

/// Base class for all application-level errors.
sealed class AppError extends Equatable implements Exception {
  const AppError({required this.message, this.cause});

  /// User-presentable explanation (never contains paths or file names).
  final String message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];

  @override
  String toString() => '$runtimeType: $message';
}

/// Why a status/media operation could not be performed.
enum MediaFailure {
  /// No folder grant yet, or the grant was revoked.
  noAccess,

  /// The chosen folder is not the expected status folder.
  wrongFolder,

  /// The source file vanished (WhatsApp expired the status, app cleared).
  sourceUnavailable,

  /// Not enough free space on the device.
  lowStorage,

  /// Source or output is unreadable/corrupt/unsupported.
  corrupt,

  /// Copy finished but verification (size/decode) failed.
  verifyFailed,

  /// Operation is not supported on this OS version/platform.
  unsupported,

  /// Anything else.
  unknown,
}

/// Media / storage access errors.
final class MediaAccessError extends AppError {
  const MediaAccessError(this.failure, {required super.message, super.cause});

  final MediaFailure failure;

  @override
  List<Object?> get props => [failure, message, cause];
}

/// Database errors.
final class DatabaseError extends AppError {
  const DatabaseError({required super.message, super.cause});
}

/// File operation errors (copy, delete, export).
final class FileOperationError extends AppError {
  const FileOperationError({required super.message, super.cause});
}

/// The user cancelled a long-running operation.
final class OperationCancelled extends AppError {
  const OperationCancelled() : super(message: 'Cancelled');
}
