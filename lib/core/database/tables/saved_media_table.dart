// lib/core/database/tables/saved_media_table.dart
//
// The WazApp library: one row per file that lives in WazApp's own storage
// (saved statuses, imported media, later: created/edited output).
// Metadata only - no file bytes. Rows are keyed by a stable random id, never
// by file name (docs/DATA_MODEL.md).

import 'package:drift/drift.dart';

@DataClassName('SavedMedia')
class SavedMediaTable extends Table {
  @override
  String get tableName => 'saved_media';

  /// Stable random id.
  TextColumn get id => text()();

  /// Absolute path of the file inside app storage.
  TextColumn get path => text()();

  /// 'image' | 'video'.
  TextColumn get kind => text()();

  TextColumn get mimeType => text()();

  /// Display name (not necessarily the on-disk name).
  TextColumn get fileName => text()();

  IntColumn get sizeBytes => integer()();

  /// When the item entered the library.
  DateTimeColumn get savedAt => dateTime()();

  /// When the original was created/posted (status modified time), if known.
  DateTimeColumn get originalAt => dateTime().nullable()();

  /// 'status' | 'imported' | 'created' | 'edited'.
  TextColumn get sourceType => text()();

  /// 'whatsapp' | 'business' for status items, else null.
  TextColumn get sourceApp => text().nullable()();

  /// Identity of the original, used to warn about re-saving the same status.
  TextColumn get sourceKey => text().nullable().unique()();

  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();

  /// Reserved for the Private Folder (excluded from ordinary queries).
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();

  /// Cached thumbnail file (JPEG) inside app storage, if generated.
  TextColumn get thumbnailPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
