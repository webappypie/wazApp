// lib/core/database/tables/media_items_table.dart
//
// Drift table definition for indexed media items (REQ-IDX-01).
// Schema version 2. Added in Phase 3.
//
// RULES:
// - contentUri is the stable reference to all file operations (PRD §5.2).
//   Never store a raw file path — paths change across renames/moves.
// - No file content bytes stored here — metadata only (P-02).
// - sourceApp distinguishes WhatsApp (com.whatsapp) vs WA Business (com.whatsapp.w4b)
//   for separate treatment in category screens (REQ-IDX-06).

import 'package:drift/drift.dart';

/// Indexed media items — one row per unique content URI.
class MediaItems extends Table {
  // ----- Identity -----

  /// Internal autoincrement PK (used only for Drift row identity).
  IntColumn get id => integer().autoIncrement()();

  /// MediaStore content URI, e.g. content://media/external/images/media/12345
  /// This is the canonical identifier for all file operations.
  TextColumn get contentUri => text().unique()();

  /// MediaStore _ID value (long). Stored as text to avoid int overflow edge cases.
  TextColumn get mediaStoreId => text()();

  // ----- Classification -----

  /// MIME type, e.g. image/jpeg, video/mp4, audio/ogg.
  TextColumn get mimeType => text()();

  /// Source app package: 'com.whatsapp' or 'com.whatsapp.w4b' (REQ-IDX-06).
  TextColumn get sourceApp => text()();

  /// MediaStore bucket / folder name, e.g. 'WhatsApp Images'.
  TextColumn get bucketName => text()();

  /// Display filename, e.g. IMG-20240315-WA0001.jpg.
  TextColumn get displayName => text()();

  // ----- Dimensions & duration -----

  /// File size in bytes.
  IntColumn get sizeBytes => integer()();

  /// Image width in pixels (0 for audio).
  IntColumn get width => integer().withDefault(const Constant(0))();

  /// Image height in pixels (0 for audio).
  IntColumn get height => integer().withDefault(const Constant(0))();

  /// Video/audio duration in milliseconds (0 for images).
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  // ----- Timestamps (seconds since epoch, as reported by MediaStore) -----

  IntColumn get dateAddedSec => integer()();
  IntColumn get dateModifiedSec => integer()();

  // ----- Indexing bookkeeping -----

  /// The scan pass that last touched this row. Used to detect deleted files.
  IntColumn get scanVersion => integer()();

  /// True if the user has explicitly protected this item (REQ-ACT-05).
  BoolColumn get isProtected =>
      boolean().withDefault(const Constant(false))();

  // Performance indexes are applied via @TableIndex annotations on the class
  // or via custom migration SQL in AppDatabase.onUpgrade when needed.
  // Columns queried most: sourceApp, bucketName, dateModifiedSec, sizeBytes,
  // scanVersion. Drift generates a primary-key index on `id` automatically.
}
