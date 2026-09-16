// lib/core/error/app_error.dart
//
// Typed error hierarchy for WappTidy.
// All domain errors extend AppError. Raw exceptions must be caught at the
// data/service boundary and converted before surfacing to the UI.

import 'package:equatable/equatable.dart';

/// Base class for all application-level errors.
sealed class AppError extends Equatable implements Exception {
  const AppError({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];

  @override
  String toString() => '$runtimeType: $message';
}

/// Media / storage access errors.
final class MediaAccessError extends AppError {
  const MediaAccessError({required super.message, super.cause});
}

/// Permission-related errors.
final class PermissionError extends AppError {
  const PermissionError({required super.message, super.cause});
}

/// Database errors.
final class DatabaseError extends AppError {
  const DatabaseError({required super.message, super.cause});
}

/// File operation errors (move, copy, delete).
final class FileOperationError extends AppError {
  const FileOperationError({required super.message, super.cause});
}

/// Remote config / Firebase errors — always non-fatal; caller must use local default.
final class RemoteConfigError extends AppError {
  const RemoteConfigError({required super.message, super.cause});
}

/// Purchase / billing errors.
final class PurchaseError extends AppError {
  const PurchaseError({required super.message, super.cause});
}

/// Analytics errors — always non-fatal.
final class AnalyticsError extends AppError {
  const AnalyticsError({required super.message, super.cause});
}
