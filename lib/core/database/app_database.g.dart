// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SavedMediaTableTable extends SavedMediaTable
    with TableInfo<$SavedMediaTableTable, SavedMedia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMediaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalAtMeta = const VerificationMeta(
    'originalAt',
  );
  @override
  late final GeneratedColumn<DateTime> originalAt = GeneratedColumn<DateTime>(
    'original_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAppMeta = const VerificationMeta(
    'sourceApp',
  );
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
    'source_app',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFavouriteMeta = const VerificationMeta(
    'isFavourite',
  );
  @override
  late final GeneratedColumn<bool> isFavourite = GeneratedColumn<bool>(
    'is_favourite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favourite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    kind,
    mimeType,
    fileName,
    sizeBytes,
    savedAt,
    originalAt,
    sourceType,
    sourceApp,
    sourceKey,
    width,
    height,
    durationMs,
    isFavourite,
    isPrivate,
    isEdited,
    thumbnailPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMedia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    if (data.containsKey('original_at')) {
      context.handle(
        _originalAtMeta,
        originalAt.isAcceptableOrUnknown(data['original_at']!, _originalAtMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_app')) {
      context.handle(
        _sourceAppMeta,
        sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta),
      );
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('is_favourite')) {
      context.handle(
        _isFavouriteMeta,
        isFavourite.isAcceptableOrUnknown(
          data['is_favourite']!,
          _isFavouriteMeta,
        ),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMedia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMedia(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
      originalAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}original_at'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_app'],
      ),
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      isFavourite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favourite'],
      )!,
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
    );
  }

  @override
  $SavedMediaTableTable createAlias(String alias) {
    return $SavedMediaTableTable(attachedDatabase, alias);
  }
}

class SavedMedia extends DataClass implements Insertable<SavedMedia> {
  /// Stable random id.
  final String id;

  /// Absolute path of the file inside app storage.
  final String path;

  /// 'image' | 'video'.
  final String kind;
  final String mimeType;

  /// Display name (not necessarily the on-disk name).
  final String fileName;
  final int sizeBytes;

  /// When the item entered the library.
  final DateTime savedAt;

  /// When the original was created/posted (status modified time), if known.
  final DateTime? originalAt;

  /// 'status' | 'imported' | 'created' | 'edited'.
  final String sourceType;

  /// 'whatsapp' | 'business' for status items, else null.
  final String? sourceApp;

  /// Identity of the original, used to warn about re-saving the same status.
  final String? sourceKey;
  final int width;
  final int height;
  final int durationMs;
  final bool isFavourite;

  /// Reserved for the Private Folder (excluded from ordinary queries).
  final bool isPrivate;
  final bool isEdited;

  /// Cached thumbnail file (JPEG) inside app storage, if generated.
  final String? thumbnailPath;
  const SavedMedia({
    required this.id,
    required this.path,
    required this.kind,
    required this.mimeType,
    required this.fileName,
    required this.sizeBytes,
    required this.savedAt,
    this.originalAt,
    required this.sourceType,
    this.sourceApp,
    this.sourceKey,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.isFavourite,
    required this.isPrivate,
    required this.isEdited,
    this.thumbnailPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['path'] = Variable<String>(path);
    map['kind'] = Variable<String>(kind);
    map['mime_type'] = Variable<String>(mimeType);
    map['file_name'] = Variable<String>(fileName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['saved_at'] = Variable<DateTime>(savedAt);
    if (!nullToAbsent || originalAt != null) {
      map['original_at'] = Variable<DateTime>(originalAt);
    }
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceApp != null) {
      map['source_app'] = Variable<String>(sourceApp);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['duration_ms'] = Variable<int>(durationMs);
    map['is_favourite'] = Variable<bool>(isFavourite);
    map['is_private'] = Variable<bool>(isPrivate);
    map['is_edited'] = Variable<bool>(isEdited);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    return map;
  }

  SavedMediaTableCompanion toCompanion(bool nullToAbsent) {
    return SavedMediaTableCompanion(
      id: Value(id),
      path: Value(path),
      kind: Value(kind),
      mimeType: Value(mimeType),
      fileName: Value(fileName),
      sizeBytes: Value(sizeBytes),
      savedAt: Value(savedAt),
      originalAt: originalAt == null && nullToAbsent
          ? const Value.absent()
          : Value(originalAt),
      sourceType: Value(sourceType),
      sourceApp: sourceApp == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceApp),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      width: Value(width),
      height: Value(height),
      durationMs: Value(durationMs),
      isFavourite: Value(isFavourite),
      isPrivate: Value(isPrivate),
      isEdited: Value(isEdited),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
    );
  }

  factory SavedMedia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMedia(
      id: serializer.fromJson<String>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      kind: serializer.fromJson<String>(json['kind']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
      originalAt: serializer.fromJson<DateTime?>(json['originalAt']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceApp: serializer.fromJson<String?>(json['sourceApp']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      isFavourite: serializer.fromJson<bool>(json['isFavourite']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'path': serializer.toJson<String>(path),
      'kind': serializer.toJson<String>(kind),
      'mimeType': serializer.toJson<String>(mimeType),
      'fileName': serializer.toJson<String>(fileName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'savedAt': serializer.toJson<DateTime>(savedAt),
      'originalAt': serializer.toJson<DateTime?>(originalAt),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceApp': serializer.toJson<String?>(sourceApp),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'durationMs': serializer.toJson<int>(durationMs),
      'isFavourite': serializer.toJson<bool>(isFavourite),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'isEdited': serializer.toJson<bool>(isEdited),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
    };
  }

  SavedMedia copyWith({
    String? id,
    String? path,
    String? kind,
    String? mimeType,
    String? fileName,
    int? sizeBytes,
    DateTime? savedAt,
    Value<DateTime?> originalAt = const Value.absent(),
    String? sourceType,
    Value<String?> sourceApp = const Value.absent(),
    Value<String?> sourceKey = const Value.absent(),
    int? width,
    int? height,
    int? durationMs,
    bool? isFavourite,
    bool? isPrivate,
    bool? isEdited,
    Value<String?> thumbnailPath = const Value.absent(),
  }) => SavedMedia(
    id: id ?? this.id,
    path: path ?? this.path,
    kind: kind ?? this.kind,
    mimeType: mimeType ?? this.mimeType,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    savedAt: savedAt ?? this.savedAt,
    originalAt: originalAt.present ? originalAt.value : this.originalAt,
    sourceType: sourceType ?? this.sourceType,
    sourceApp: sourceApp.present ? sourceApp.value : this.sourceApp,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
    width: width ?? this.width,
    height: height ?? this.height,
    durationMs: durationMs ?? this.durationMs,
    isFavourite: isFavourite ?? this.isFavourite,
    isPrivate: isPrivate ?? this.isPrivate,
    isEdited: isEdited ?? this.isEdited,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
  );
  SavedMedia copyWithCompanion(SavedMediaTableCompanion data) {
    return SavedMedia(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      kind: data.kind.present ? data.kind.value : this.kind,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      originalAt: data.originalAt.present
          ? data.originalAt.value
          : this.originalAt,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      isFavourite: data.isFavourite.present
          ? data.isFavourite.value
          : this.isFavourite,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMedia(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('savedAt: $savedAt, ')
          ..write('originalAt: $originalAt, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('isEdited: $isEdited, ')
          ..write('thumbnailPath: $thumbnailPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    kind,
    mimeType,
    fileName,
    sizeBytes,
    savedAt,
    originalAt,
    sourceType,
    sourceApp,
    sourceKey,
    width,
    height,
    durationMs,
    isFavourite,
    isPrivate,
    isEdited,
    thumbnailPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMedia &&
          other.id == this.id &&
          other.path == this.path &&
          other.kind == this.kind &&
          other.mimeType == this.mimeType &&
          other.fileName == this.fileName &&
          other.sizeBytes == this.sizeBytes &&
          other.savedAt == this.savedAt &&
          other.originalAt == this.originalAt &&
          other.sourceType == this.sourceType &&
          other.sourceApp == this.sourceApp &&
          other.sourceKey == this.sourceKey &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.isFavourite == this.isFavourite &&
          other.isPrivate == this.isPrivate &&
          other.isEdited == this.isEdited &&
          other.thumbnailPath == this.thumbnailPath);
}

class SavedMediaTableCompanion extends UpdateCompanion<SavedMedia> {
  final Value<String> id;
  final Value<String> path;
  final Value<String> kind;
  final Value<String> mimeType;
  final Value<String> fileName;
  final Value<int> sizeBytes;
  final Value<DateTime> savedAt;
  final Value<DateTime?> originalAt;
  final Value<String> sourceType;
  final Value<String?> sourceApp;
  final Value<String?> sourceKey;
  final Value<int> width;
  final Value<int> height;
  final Value<int> durationMs;
  final Value<bool> isFavourite;
  final Value<bool> isPrivate;
  final Value<bool> isEdited;
  final Value<String?> thumbnailPath;
  final Value<int> rowid;
  const SavedMediaTableCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.kind = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.originalAt = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedMediaTableCompanion.insert({
    required String id,
    required String path,
    required String kind,
    required String mimeType,
    required String fileName,
    required int sizeBytes,
    required DateTime savedAt,
    this.originalAt = const Value.absent(),
    required String sourceType,
    this.sourceApp = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       path = Value(path),
       kind = Value(kind),
       mimeType = Value(mimeType),
       fileName = Value(fileName),
       sizeBytes = Value(sizeBytes),
       savedAt = Value(savedAt),
       sourceType = Value(sourceType);
  static Insertable<SavedMedia> custom({
    Expression<String>? id,
    Expression<String>? path,
    Expression<String>? kind,
    Expression<String>? mimeType,
    Expression<String>? fileName,
    Expression<int>? sizeBytes,
    Expression<DateTime>? savedAt,
    Expression<DateTime>? originalAt,
    Expression<String>? sourceType,
    Expression<String>? sourceApp,
    Expression<String>? sourceKey,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<bool>? isFavourite,
    Expression<bool>? isPrivate,
    Expression<bool>? isEdited,
    Expression<String>? thumbnailPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (kind != null) 'kind': kind,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (savedAt != null) 'saved_at': savedAt,
      if (originalAt != null) 'original_at': originalAt,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceApp != null) 'source_app': sourceApp,
      if (sourceKey != null) 'source_key': sourceKey,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (isFavourite != null) 'is_favourite': isFavourite,
      if (isPrivate != null) 'is_private': isPrivate,
      if (isEdited != null) 'is_edited': isEdited,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedMediaTableCompanion copyWith({
    Value<String>? id,
    Value<String>? path,
    Value<String>? kind,
    Value<String>? mimeType,
    Value<String>? fileName,
    Value<int>? sizeBytes,
    Value<DateTime>? savedAt,
    Value<DateTime?>? originalAt,
    Value<String>? sourceType,
    Value<String?>? sourceApp,
    Value<String?>? sourceKey,
    Value<int>? width,
    Value<int>? height,
    Value<int>? durationMs,
    Value<bool>? isFavourite,
    Value<bool>? isPrivate,
    Value<bool>? isEdited,
    Value<String?>? thumbnailPath,
    Value<int>? rowid,
  }) {
    return SavedMediaTableCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      kind: kind ?? this.kind,
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      savedAt: savedAt ?? this.savedAt,
      originalAt: originalAt ?? this.originalAt,
      sourceType: sourceType ?? this.sourceType,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceKey: sourceKey ?? this.sourceKey,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      isFavourite: isFavourite ?? this.isFavourite,
      isPrivate: isPrivate ?? this.isPrivate,
      isEdited: isEdited ?? this.isEdited,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (originalAt.present) {
      map['original_at'] = Variable<DateTime>(originalAt.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (isFavourite.present) {
      map['is_favourite'] = Variable<bool>(isFavourite.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMediaTableCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('savedAt: $savedAt, ')
          ..write('originalAt: $originalAt, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('isEdited: $isEdited, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedMediaTableTable savedMediaTable = $SavedMediaTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [savedMediaTable];
}

typedef $$SavedMediaTableTableCreateCompanionBuilder =
    SavedMediaTableCompanion Function({
      required String id,
      required String path,
      required String kind,
      required String mimeType,
      required String fileName,
      required int sizeBytes,
      required DateTime savedAt,
      Value<DateTime?> originalAt,
      required String sourceType,
      Value<String?> sourceApp,
      Value<String?> sourceKey,
      Value<int> width,
      Value<int> height,
      Value<int> durationMs,
      Value<bool> isFavourite,
      Value<bool> isPrivate,
      Value<bool> isEdited,
      Value<String?> thumbnailPath,
      Value<int> rowid,
    });
typedef $$SavedMediaTableTableUpdateCompanionBuilder =
    SavedMediaTableCompanion Function({
      Value<String> id,
      Value<String> path,
      Value<String> kind,
      Value<String> mimeType,
      Value<String> fileName,
      Value<int> sizeBytes,
      Value<DateTime> savedAt,
      Value<DateTime?> originalAt,
      Value<String> sourceType,
      Value<String?> sourceApp,
      Value<String?> sourceKey,
      Value<int> width,
      Value<int> height,
      Value<int> durationMs,
      Value<bool> isFavourite,
      Value<bool> isPrivate,
      Value<bool> isEdited,
      Value<String?> thumbnailPath,
      Value<int> rowid,
    });

class $$SavedMediaTableTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMediaTableTable> {
  $$SavedMediaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get originalAt => $composableBuilder(
    column: $table.originalAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedMediaTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMediaTableTable> {
  $$SavedMediaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get originalAt => $composableBuilder(
    column: $table.originalAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedMediaTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMediaTableTable> {
  $$SavedMediaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get originalAt => $composableBuilder(
    column: $table.originalAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );
}

class $$SavedMediaTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMediaTableTable,
          SavedMedia,
          $$SavedMediaTableTableFilterComposer,
          $$SavedMediaTableTableOrderingComposer,
          $$SavedMediaTableTableAnnotationComposer,
          $$SavedMediaTableTableCreateCompanionBuilder,
          $$SavedMediaTableTableUpdateCompanionBuilder,
          (
            SavedMedia,
            BaseReferences<_$AppDatabase, $SavedMediaTableTable, SavedMedia>,
          ),
          SavedMedia,
          PrefetchHooks Function()
        > {
  $$SavedMediaTableTableTableManager(
    _$AppDatabase db,
    $SavedMediaTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMediaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMediaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMediaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<DateTime?> originalAt = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceApp = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedMediaTableCompanion(
                id: id,
                path: path,
                kind: kind,
                mimeType: mimeType,
                fileName: fileName,
                sizeBytes: sizeBytes,
                savedAt: savedAt,
                originalAt: originalAt,
                sourceType: sourceType,
                sourceApp: sourceApp,
                sourceKey: sourceKey,
                width: width,
                height: height,
                durationMs: durationMs,
                isFavourite: isFavourite,
                isPrivate: isPrivate,
                isEdited: isEdited,
                thumbnailPath: thumbnailPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String path,
                required String kind,
                required String mimeType,
                required String fileName,
                required int sizeBytes,
                required DateTime savedAt,
                Value<DateTime?> originalAt = const Value.absent(),
                required String sourceType,
                Value<String?> sourceApp = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedMediaTableCompanion.insert(
                id: id,
                path: path,
                kind: kind,
                mimeType: mimeType,
                fileName: fileName,
                sizeBytes: sizeBytes,
                savedAt: savedAt,
                originalAt: originalAt,
                sourceType: sourceType,
                sourceApp: sourceApp,
                sourceKey: sourceKey,
                width: width,
                height: height,
                durationMs: durationMs,
                isFavourite: isFavourite,
                isPrivate: isPrivate,
                isEdited: isEdited,
                thumbnailPath: thumbnailPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedMediaTableTable, SavedMedia>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SavedMediaTableTable,
                    SavedMedia
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedMediaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMediaTableTable,
      SavedMedia,
      $$SavedMediaTableTableFilterComposer,
      $$SavedMediaTableTableOrderingComposer,
      $$SavedMediaTableTableAnnotationComposer,
      $$SavedMediaTableTableCreateCompanionBuilder,
      $$SavedMediaTableTableUpdateCompanionBuilder,
      (
        SavedMedia,
        BaseReferences<_$AppDatabase, $SavedMediaTableTable, SavedMedia>,
      ),
      SavedMedia,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedMediaTableTableTableManager get savedMediaTable =>
      $$SavedMediaTableTableTableManager(_db, _db.savedMediaTable);
}
