// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentUriMeta = const VerificationMeta(
    'contentUri',
  );
  @override
  late final GeneratedColumn<String> contentUri = GeneratedColumn<String>(
    'content_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mediaStoreIdMeta = const VerificationMeta(
    'mediaStoreId',
  );
  @override
  late final GeneratedColumn<String> mediaStoreId = GeneratedColumn<String>(
    'media_store_id',
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
  static const VerificationMeta _sourceAppMeta = const VerificationMeta(
    'sourceApp',
  );
  @override
  late final GeneratedColumn<String> sourceApp = GeneratedColumn<String>(
    'source_app',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketNameMeta = const VerificationMeta(
    'bucketName',
  );
  @override
  late final GeneratedColumn<String> bucketName = GeneratedColumn<String>(
    'bucket_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
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
  static const VerificationMeta _dateAddedSecMeta = const VerificationMeta(
    'dateAddedSec',
  );
  @override
  late final GeneratedColumn<int> dateAddedSec = GeneratedColumn<int>(
    'date_added_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateModifiedSecMeta = const VerificationMeta(
    'dateModifiedSec',
  );
  @override
  late final GeneratedColumn<int> dateModifiedSec = GeneratedColumn<int>(
    'date_modified_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanVersionMeta = const VerificationMeta(
    'scanVersion',
  );
  @override
  late final GeneratedColumn<int> scanVersion = GeneratedColumn<int>(
    'scan_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isProtectedMeta = const VerificationMeta(
    'isProtected',
  );
  @override
  late final GeneratedColumn<bool> isProtected = GeneratedColumn<bool>(
    'is_protected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_protected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentUri,
    mediaStoreId,
    mimeType,
    sourceApp,
    bucketName,
    displayName,
    sizeBytes,
    width,
    height,
    durationMs,
    dateAddedSec,
    dateModifiedSec,
    scanVersion,
    isProtected,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_uri')) {
      context.handle(
        _contentUriMeta,
        contentUri.isAcceptableOrUnknown(data['content_uri']!, _contentUriMeta),
      );
    } else if (isInserting) {
      context.missing(_contentUriMeta);
    }
    if (data.containsKey('media_store_id')) {
      context.handle(
        _mediaStoreIdMeta,
        mediaStoreId.isAcceptableOrUnknown(
          data['media_store_id']!,
          _mediaStoreIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaStoreIdMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('source_app')) {
      context.handle(
        _sourceAppMeta,
        sourceApp.isAcceptableOrUnknown(data['source_app']!, _sourceAppMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceAppMeta);
    }
    if (data.containsKey('bucket_name')) {
      context.handle(
        _bucketNameMeta,
        bucketName.isAcceptableOrUnknown(data['bucket_name']!, _bucketNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
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
    if (data.containsKey('date_added_sec')) {
      context.handle(
        _dateAddedSecMeta,
        dateAddedSec.isAcceptableOrUnknown(
          data['date_added_sec']!,
          _dateAddedSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateAddedSecMeta);
    }
    if (data.containsKey('date_modified_sec')) {
      context.handle(
        _dateModifiedSecMeta,
        dateModifiedSec.isAcceptableOrUnknown(
          data['date_modified_sec']!,
          _dateModifiedSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateModifiedSecMeta);
    }
    if (data.containsKey('scan_version')) {
      context.handle(
        _scanVersionMeta,
        scanVersion.isAcceptableOrUnknown(
          data['scan_version']!,
          _scanVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scanVersionMeta);
    }
    if (data.containsKey('is_protected')) {
      context.handle(
        _isProtectedMeta,
        isProtected.isAcceptableOrUnknown(
          data['is_protected']!,
          _isProtectedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uri'],
      )!,
      mediaStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_store_id'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sourceApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_app'],
      )!,
      bucketName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
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
      dateAddedSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_added_sec'],
      )!,
      dateModifiedSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_modified_sec'],
      )!,
      scanVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scan_version'],
      )!,
      isProtected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_protected'],
      )!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItem extends DataClass implements Insertable<MediaItem> {
  /// Internal autoincrement PK (used only for Drift row identity).
  final int id;

  /// MediaStore content URI, e.g. content://media/external/images/media/12345
  /// This is the canonical identifier for all file operations.
  final String contentUri;

  /// MediaStore _ID value (long). Stored as text to avoid int overflow edge cases.
  final String mediaStoreId;

  /// MIME type, e.g. image/jpeg, video/mp4, audio/ogg.
  final String mimeType;

  /// Source app package: 'com.whatsapp' or 'com.whatsapp.w4b' (REQ-IDX-06).
  final String sourceApp;

  /// MediaStore bucket / folder name, e.g. 'WhatsApp Images'.
  final String bucketName;

  /// Display filename, e.g. IMG-20240315-WA0001.jpg.
  final String displayName;

  /// File size in bytes.
  final int sizeBytes;

  /// Image width in pixels (0 for audio).
  final int width;

  /// Image height in pixels (0 for audio).
  final int height;

  /// Video/audio duration in milliseconds (0 for images).
  final int durationMs;
  final int dateAddedSec;
  final int dateModifiedSec;

  /// The scan pass that last touched this row. Used to detect deleted files.
  final int scanVersion;

  /// True if the user has explicitly protected this item (REQ-ACT-05).
  final bool isProtected;
  const MediaItem({
    required this.id,
    required this.contentUri,
    required this.mediaStoreId,
    required this.mimeType,
    required this.sourceApp,
    required this.bucketName,
    required this.displayName,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.dateAddedSec,
    required this.dateModifiedSec,
    required this.scanVersion,
    required this.isProtected,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_uri'] = Variable<String>(contentUri);
    map['media_store_id'] = Variable<String>(mediaStoreId);
    map['mime_type'] = Variable<String>(mimeType);
    map['source_app'] = Variable<String>(sourceApp);
    map['bucket_name'] = Variable<String>(bucketName);
    map['display_name'] = Variable<String>(displayName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['duration_ms'] = Variable<int>(durationMs);
    map['date_added_sec'] = Variable<int>(dateAddedSec);
    map['date_modified_sec'] = Variable<int>(dateModifiedSec);
    map['scan_version'] = Variable<int>(scanVersion);
    map['is_protected'] = Variable<bool>(isProtected);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      contentUri: Value(contentUri),
      mediaStoreId: Value(mediaStoreId),
      mimeType: Value(mimeType),
      sourceApp: Value(sourceApp),
      bucketName: Value(bucketName),
      displayName: Value(displayName),
      sizeBytes: Value(sizeBytes),
      width: Value(width),
      height: Value(height),
      durationMs: Value(durationMs),
      dateAddedSec: Value(dateAddedSec),
      dateModifiedSec: Value(dateModifiedSec),
      scanVersion: Value(scanVersion),
      isProtected: Value(isProtected),
    );
  }

  factory MediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItem(
      id: serializer.fromJson<int>(json['id']),
      contentUri: serializer.fromJson<String>(json['contentUri']),
      mediaStoreId: serializer.fromJson<String>(json['mediaStoreId']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sourceApp: serializer.fromJson<String>(json['sourceApp']),
      bucketName: serializer.fromJson<String>(json['bucketName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      dateAddedSec: serializer.fromJson<int>(json['dateAddedSec']),
      dateModifiedSec: serializer.fromJson<int>(json['dateModifiedSec']),
      scanVersion: serializer.fromJson<int>(json['scanVersion']),
      isProtected: serializer.fromJson<bool>(json['isProtected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentUri': serializer.toJson<String>(contentUri),
      'mediaStoreId': serializer.toJson<String>(mediaStoreId),
      'mimeType': serializer.toJson<String>(mimeType),
      'sourceApp': serializer.toJson<String>(sourceApp),
      'bucketName': serializer.toJson<String>(bucketName),
      'displayName': serializer.toJson<String>(displayName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'durationMs': serializer.toJson<int>(durationMs),
      'dateAddedSec': serializer.toJson<int>(dateAddedSec),
      'dateModifiedSec': serializer.toJson<int>(dateModifiedSec),
      'scanVersion': serializer.toJson<int>(scanVersion),
      'isProtected': serializer.toJson<bool>(isProtected),
    };
  }

  MediaItem copyWith({
    int? id,
    String? contentUri,
    String? mediaStoreId,
    String? mimeType,
    String? sourceApp,
    String? bucketName,
    String? displayName,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationMs,
    int? dateAddedSec,
    int? dateModifiedSec,
    int? scanVersion,
    bool? isProtected,
  }) => MediaItem(
    id: id ?? this.id,
    contentUri: contentUri ?? this.contentUri,
    mediaStoreId: mediaStoreId ?? this.mediaStoreId,
    mimeType: mimeType ?? this.mimeType,
    sourceApp: sourceApp ?? this.sourceApp,
    bucketName: bucketName ?? this.bucketName,
    displayName: displayName ?? this.displayName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    width: width ?? this.width,
    height: height ?? this.height,
    durationMs: durationMs ?? this.durationMs,
    dateAddedSec: dateAddedSec ?? this.dateAddedSec,
    dateModifiedSec: dateModifiedSec ?? this.dateModifiedSec,
    scanVersion: scanVersion ?? this.scanVersion,
    isProtected: isProtected ?? this.isProtected,
  );
  MediaItem copyWithCompanion(MediaItemsCompanion data) {
    return MediaItem(
      id: data.id.present ? data.id.value : this.id,
      contentUri: data.contentUri.present
          ? data.contentUri.value
          : this.contentUri,
      mediaStoreId: data.mediaStoreId.present
          ? data.mediaStoreId.value
          : this.mediaStoreId,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sourceApp: data.sourceApp.present ? data.sourceApp.value : this.sourceApp,
      bucketName: data.bucketName.present
          ? data.bucketName.value
          : this.bucketName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      dateAddedSec: data.dateAddedSec.present
          ? data.dateAddedSec.value
          : this.dateAddedSec,
      dateModifiedSec: data.dateModifiedSec.present
          ? data.dateModifiedSec.value
          : this.dateModifiedSec,
      scanVersion: data.scanVersion.present
          ? data.scanVersion.value
          : this.scanVersion,
      isProtected: data.isProtected.present
          ? data.isProtected.value
          : this.isProtected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItem(')
          ..write('id: $id, ')
          ..write('contentUri: $contentUri, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('mimeType: $mimeType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('bucketName: $bucketName, ')
          ..write('displayName: $displayName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('dateAddedSec: $dateAddedSec, ')
          ..write('dateModifiedSec: $dateModifiedSec, ')
          ..write('scanVersion: $scanVersion, ')
          ..write('isProtected: $isProtected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contentUri,
    mediaStoreId,
    mimeType,
    sourceApp,
    bucketName,
    displayName,
    sizeBytes,
    width,
    height,
    durationMs,
    dateAddedSec,
    dateModifiedSec,
    scanVersion,
    isProtected,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItem &&
          other.id == this.id &&
          other.contentUri == this.contentUri &&
          other.mediaStoreId == this.mediaStoreId &&
          other.mimeType == this.mimeType &&
          other.sourceApp == this.sourceApp &&
          other.bucketName == this.bucketName &&
          other.displayName == this.displayName &&
          other.sizeBytes == this.sizeBytes &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.dateAddedSec == this.dateAddedSec &&
          other.dateModifiedSec == this.dateModifiedSec &&
          other.scanVersion == this.scanVersion &&
          other.isProtected == this.isProtected);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItem> {
  final Value<int> id;
  final Value<String> contentUri;
  final Value<String> mediaStoreId;
  final Value<String> mimeType;
  final Value<String> sourceApp;
  final Value<String> bucketName;
  final Value<String> displayName;
  final Value<int> sizeBytes;
  final Value<int> width;
  final Value<int> height;
  final Value<int> durationMs;
  final Value<int> dateAddedSec;
  final Value<int> dateModifiedSec;
  final Value<int> scanVersion;
  final Value<bool> isProtected;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.mediaStoreId = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sourceApp = const Value.absent(),
    this.bucketName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.dateAddedSec = const Value.absent(),
    this.dateModifiedSec = const Value.absent(),
    this.scanVersion = const Value.absent(),
    this.isProtected = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    this.id = const Value.absent(),
    required String contentUri,
    required String mediaStoreId,
    required String mimeType,
    required String sourceApp,
    required String bucketName,
    required String displayName,
    required int sizeBytes,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int dateAddedSec,
    required int dateModifiedSec,
    required int scanVersion,
    this.isProtected = const Value.absent(),
  }) : contentUri = Value(contentUri),
       mediaStoreId = Value(mediaStoreId),
       mimeType = Value(mimeType),
       sourceApp = Value(sourceApp),
       bucketName = Value(bucketName),
       displayName = Value(displayName),
       sizeBytes = Value(sizeBytes),
       dateAddedSec = Value(dateAddedSec),
       dateModifiedSec = Value(dateModifiedSec),
       scanVersion = Value(scanVersion);
  static Insertable<MediaItem> custom({
    Expression<int>? id,
    Expression<String>? contentUri,
    Expression<String>? mediaStoreId,
    Expression<String>? mimeType,
    Expression<String>? sourceApp,
    Expression<String>? bucketName,
    Expression<String>? displayName,
    Expression<int>? sizeBytes,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<int>? dateAddedSec,
    Expression<int>? dateModifiedSec,
    Expression<int>? scanVersion,
    Expression<bool>? isProtected,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentUri != null) 'content_uri': contentUri,
      if (mediaStoreId != null) 'media_store_id': mediaStoreId,
      if (mimeType != null) 'mime_type': mimeType,
      if (sourceApp != null) 'source_app': sourceApp,
      if (bucketName != null) 'bucket_name': bucketName,
      if (displayName != null) 'display_name': displayName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (dateAddedSec != null) 'date_added_sec': dateAddedSec,
      if (dateModifiedSec != null) 'date_modified_sec': dateModifiedSec,
      if (scanVersion != null) 'scan_version': scanVersion,
      if (isProtected != null) 'is_protected': isProtected,
    });
  }

  MediaItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? contentUri,
    Value<String>? mediaStoreId,
    Value<String>? mimeType,
    Value<String>? sourceApp,
    Value<String>? bucketName,
    Value<String>? displayName,
    Value<int>? sizeBytes,
    Value<int>? width,
    Value<int>? height,
    Value<int>? durationMs,
    Value<int>? dateAddedSec,
    Value<int>? dateModifiedSec,
    Value<int>? scanVersion,
    Value<bool>? isProtected,
  }) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      contentUri: contentUri ?? this.contentUri,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      mimeType: mimeType ?? this.mimeType,
      sourceApp: sourceApp ?? this.sourceApp,
      bucketName: bucketName ?? this.bucketName,
      displayName: displayName ?? this.displayName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      dateAddedSec: dateAddedSec ?? this.dateAddedSec,
      dateModifiedSec: dateModifiedSec ?? this.dateModifiedSec,
      scanVersion: scanVersion ?? this.scanVersion,
      isProtected: isProtected ?? this.isProtected,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentUri.present) {
      map['content_uri'] = Variable<String>(contentUri.value);
    }
    if (mediaStoreId.present) {
      map['media_store_id'] = Variable<String>(mediaStoreId.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sourceApp.present) {
      map['source_app'] = Variable<String>(sourceApp.value);
    }
    if (bucketName.present) {
      map['bucket_name'] = Variable<String>(bucketName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
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
    if (dateAddedSec.present) {
      map['date_added_sec'] = Variable<int>(dateAddedSec.value);
    }
    if (dateModifiedSec.present) {
      map['date_modified_sec'] = Variable<int>(dateModifiedSec.value);
    }
    if (scanVersion.present) {
      map['scan_version'] = Variable<int>(scanVersion.value);
    }
    if (isProtected.present) {
      map['is_protected'] = Variable<bool>(isProtected.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('contentUri: $contentUri, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('mimeType: $mimeType, ')
          ..write('sourceApp: $sourceApp, ')
          ..write('bucketName: $bucketName, ')
          ..write('displayName: $displayName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('dateAddedSec: $dateAddedSec, ')
          ..write('dateModifiedSec: $dateModifiedSec, ')
          ..write('scanVersion: $scanVersion, ')
          ..write('isProtected: $isProtected')
          ..write(')'))
        .toString();
  }
}

class $ScanStateTableTable extends ScanStateTable
    with TableInfo<$ScanStateTableTable, ScanStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _currentScanVersionMeta =
      const VerificationMeta('currentScanVersion');
  @override
  late final GeneratedColumn<int> currentScanVersion = GeneratedColumn<int>(
    'current_scan_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itemsProcessedMeta = const VerificationMeta(
    'itemsProcessed',
  );
  @override
  late final GeneratedColumn<int> itemsProcessed = GeneratedColumn<int>(
    'items_processed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itemsTotalMeta = const VerificationMeta(
    'itemsTotal',
  );
  @override
  late final GeneratedColumn<int> itemsTotal = GeneratedColumn<int>(
    'items_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesProcessedMeta = const VerificationMeta(
    'bytesProcessed',
  );
  @override
  late final GeneratedColumn<int> bytesProcessed = GeneratedColumn<int>(
    'bytes_processed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenGenerationMeta =
      const VerificationMeta('lastSeenGeneration');
  @override
  late final GeneratedColumn<int> lastSeenGeneration = GeneratedColumn<int>(
    'last_seen_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastModifiedCursorMeta =
      const VerificationMeta('lastModifiedCursor');
  @override
  late final GeneratedColumn<int> lastModifiedCursor = GeneratedColumn<int>(
    'last_modified_cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    currentScanVersion,
    itemsProcessed,
    itemsTotal,
    bytesProcessed,
    lastSeenGeneration,
    lastModifiedCursor,
    startedAtMs,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanStateTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('current_scan_version')) {
      context.handle(
        _currentScanVersionMeta,
        currentScanVersion.isAcceptableOrUnknown(
          data['current_scan_version']!,
          _currentScanVersionMeta,
        ),
      );
    }
    if (data.containsKey('items_processed')) {
      context.handle(
        _itemsProcessedMeta,
        itemsProcessed.isAcceptableOrUnknown(
          data['items_processed']!,
          _itemsProcessedMeta,
        ),
      );
    }
    if (data.containsKey('items_total')) {
      context.handle(
        _itemsTotalMeta,
        itemsTotal.isAcceptableOrUnknown(data['items_total']!, _itemsTotalMeta),
      );
    }
    if (data.containsKey('bytes_processed')) {
      context.handle(
        _bytesProcessedMeta,
        bytesProcessed.isAcceptableOrUnknown(
          data['bytes_processed']!,
          _bytesProcessedMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_generation')) {
      context.handle(
        _lastSeenGenerationMeta,
        lastSeenGeneration.isAcceptableOrUnknown(
          data['last_seen_generation']!,
          _lastSeenGenerationMeta,
        ),
      );
    }
    if (data.containsKey('last_modified_cursor')) {
      context.handle(
        _lastModifiedCursorMeta,
        lastModifiedCursor.isAcceptableOrUnknown(
          data['last_modified_cursor']!,
          _lastModifiedCursorMeta,
        ),
      );
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanStateTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanStateTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currentScanVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_scan_version'],
      )!,
      itemsProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}items_processed'],
      )!,
      itemsTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}items_total'],
      )!,
      bytesProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_processed'],
      )!,
      lastSeenGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_generation'],
      )!,
      lastModifiedCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_modified_cursor'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $ScanStateTableTable createAlias(String alias) {
    return $ScanStateTableTable(attachedDatabase, alias);
  }
}

class ScanStateTableData extends DataClass
    implements Insertable<ScanStateTableData> {
  /// Always 1 — singleton row.
  final int id;

  /// Current state: idle | running | paused | cancelled | done | error
  final String status;

  /// The scan version number for this pass (matches MediaItems.scanVersion).
  final int currentScanVersion;

  /// Items processed so far in the current scan (monotonically non-decreasing).
  final int itemsProcessed;

  /// Total items discovered so far (updated incrementally as we learn the count).
  final int itemsTotal;

  /// Bytes processed so far.
  final int bytesProcessed;

  /// Last MediaStore generation ID seen (for incremental rescan — REQ-IDX-03).
  final int lastSeenGeneration;

  /// dateModifiedSec of the last item we successfully processed (cursor).
  /// A resumed scan queries WHERE dateModifiedSec >= this value.
  final int lastModifiedCursor;

  /// Unix timestamp (ms) when this scan started.
  final int startedAtMs;

  /// Error message if status == 'error'. Null otherwise.
  final String? errorMessage;
  const ScanStateTableData({
    required this.id,
    required this.status,
    required this.currentScanVersion,
    required this.itemsProcessed,
    required this.itemsTotal,
    required this.bytesProcessed,
    required this.lastSeenGeneration,
    required this.lastModifiedCursor,
    required this.startedAtMs,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['status'] = Variable<String>(status);
    map['current_scan_version'] = Variable<int>(currentScanVersion);
    map['items_processed'] = Variable<int>(itemsProcessed);
    map['items_total'] = Variable<int>(itemsTotal);
    map['bytes_processed'] = Variable<int>(bytesProcessed);
    map['last_seen_generation'] = Variable<int>(lastSeenGeneration);
    map['last_modified_cursor'] = Variable<int>(lastModifiedCursor);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  ScanStateTableCompanion toCompanion(bool nullToAbsent) {
    return ScanStateTableCompanion(
      id: Value(id),
      status: Value(status),
      currentScanVersion: Value(currentScanVersion),
      itemsProcessed: Value(itemsProcessed),
      itemsTotal: Value(itemsTotal),
      bytesProcessed: Value(bytesProcessed),
      lastSeenGeneration: Value(lastSeenGeneration),
      lastModifiedCursor: Value(lastModifiedCursor),
      startedAtMs: Value(startedAtMs),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory ScanStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanStateTableData(
      id: serializer.fromJson<int>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      currentScanVersion: serializer.fromJson<int>(json['currentScanVersion']),
      itemsProcessed: serializer.fromJson<int>(json['itemsProcessed']),
      itemsTotal: serializer.fromJson<int>(json['itemsTotal']),
      bytesProcessed: serializer.fromJson<int>(json['bytesProcessed']),
      lastSeenGeneration: serializer.fromJson<int>(json['lastSeenGeneration']),
      lastModifiedCursor: serializer.fromJson<int>(json['lastModifiedCursor']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<String>(status),
      'currentScanVersion': serializer.toJson<int>(currentScanVersion),
      'itemsProcessed': serializer.toJson<int>(itemsProcessed),
      'itemsTotal': serializer.toJson<int>(itemsTotal),
      'bytesProcessed': serializer.toJson<int>(bytesProcessed),
      'lastSeenGeneration': serializer.toJson<int>(lastSeenGeneration),
      'lastModifiedCursor': serializer.toJson<int>(lastModifiedCursor),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  ScanStateTableData copyWith({
    int? id,
    String? status,
    int? currentScanVersion,
    int? itemsProcessed,
    int? itemsTotal,
    int? bytesProcessed,
    int? lastSeenGeneration,
    int? lastModifiedCursor,
    int? startedAtMs,
    Value<String?> errorMessage = const Value.absent(),
  }) => ScanStateTableData(
    id: id ?? this.id,
    status: status ?? this.status,
    currentScanVersion: currentScanVersion ?? this.currentScanVersion,
    itemsProcessed: itemsProcessed ?? this.itemsProcessed,
    itemsTotal: itemsTotal ?? this.itemsTotal,
    bytesProcessed: bytesProcessed ?? this.bytesProcessed,
    lastSeenGeneration: lastSeenGeneration ?? this.lastSeenGeneration,
    lastModifiedCursor: lastModifiedCursor ?? this.lastModifiedCursor,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  ScanStateTableData copyWithCompanion(ScanStateTableCompanion data) {
    return ScanStateTableData(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      currentScanVersion: data.currentScanVersion.present
          ? data.currentScanVersion.value
          : this.currentScanVersion,
      itemsProcessed: data.itemsProcessed.present
          ? data.itemsProcessed.value
          : this.itemsProcessed,
      itemsTotal: data.itemsTotal.present
          ? data.itemsTotal.value
          : this.itemsTotal,
      bytesProcessed: data.bytesProcessed.present
          ? data.bytesProcessed.value
          : this.bytesProcessed,
      lastSeenGeneration: data.lastSeenGeneration.present
          ? data.lastSeenGeneration.value
          : this.lastSeenGeneration,
      lastModifiedCursor: data.lastModifiedCursor.present
          ? data.lastModifiedCursor.value
          : this.lastModifiedCursor,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanStateTableData(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('currentScanVersion: $currentScanVersion, ')
          ..write('itemsProcessed: $itemsProcessed, ')
          ..write('itemsTotal: $itemsTotal, ')
          ..write('bytesProcessed: $bytesProcessed, ')
          ..write('lastSeenGeneration: $lastSeenGeneration, ')
          ..write('lastModifiedCursor: $lastModifiedCursor, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    currentScanVersion,
    itemsProcessed,
    itemsTotal,
    bytesProcessed,
    lastSeenGeneration,
    lastModifiedCursor,
    startedAtMs,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanStateTableData &&
          other.id == this.id &&
          other.status == this.status &&
          other.currentScanVersion == this.currentScanVersion &&
          other.itemsProcessed == this.itemsProcessed &&
          other.itemsTotal == this.itemsTotal &&
          other.bytesProcessed == this.bytesProcessed &&
          other.lastSeenGeneration == this.lastSeenGeneration &&
          other.lastModifiedCursor == this.lastModifiedCursor &&
          other.startedAtMs == this.startedAtMs &&
          other.errorMessage == this.errorMessage);
}

class ScanStateTableCompanion extends UpdateCompanion<ScanStateTableData> {
  final Value<int> id;
  final Value<String> status;
  final Value<int> currentScanVersion;
  final Value<int> itemsProcessed;
  final Value<int> itemsTotal;
  final Value<int> bytesProcessed;
  final Value<int> lastSeenGeneration;
  final Value<int> lastModifiedCursor;
  final Value<int> startedAtMs;
  final Value<String?> errorMessage;
  const ScanStateTableCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.currentScanVersion = const Value.absent(),
    this.itemsProcessed = const Value.absent(),
    this.itemsTotal = const Value.absent(),
    this.bytesProcessed = const Value.absent(),
    this.lastSeenGeneration = const Value.absent(),
    this.lastModifiedCursor = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  ScanStateTableCompanion.insert({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.currentScanVersion = const Value.absent(),
    this.itemsProcessed = const Value.absent(),
    this.itemsTotal = const Value.absent(),
    this.bytesProcessed = const Value.absent(),
    this.lastSeenGeneration = const Value.absent(),
    this.lastModifiedCursor = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  static Insertable<ScanStateTableData> custom({
    Expression<int>? id,
    Expression<String>? status,
    Expression<int>? currentScanVersion,
    Expression<int>? itemsProcessed,
    Expression<int>? itemsTotal,
    Expression<int>? bytesProcessed,
    Expression<int>? lastSeenGeneration,
    Expression<int>? lastModifiedCursor,
    Expression<int>? startedAtMs,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (currentScanVersion != null)
        'current_scan_version': currentScanVersion,
      if (itemsProcessed != null) 'items_processed': itemsProcessed,
      if (itemsTotal != null) 'items_total': itemsTotal,
      if (bytesProcessed != null) 'bytes_processed': bytesProcessed,
      if (lastSeenGeneration != null)
        'last_seen_generation': lastSeenGeneration,
      if (lastModifiedCursor != null)
        'last_modified_cursor': lastModifiedCursor,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  ScanStateTableCompanion copyWith({
    Value<int>? id,
    Value<String>? status,
    Value<int>? currentScanVersion,
    Value<int>? itemsProcessed,
    Value<int>? itemsTotal,
    Value<int>? bytesProcessed,
    Value<int>? lastSeenGeneration,
    Value<int>? lastModifiedCursor,
    Value<int>? startedAtMs,
    Value<String?>? errorMessage,
  }) {
    return ScanStateTableCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      currentScanVersion: currentScanVersion ?? this.currentScanVersion,
      itemsProcessed: itemsProcessed ?? this.itemsProcessed,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      bytesProcessed: bytesProcessed ?? this.bytesProcessed,
      lastSeenGeneration: lastSeenGeneration ?? this.lastSeenGeneration,
      lastModifiedCursor: lastModifiedCursor ?? this.lastModifiedCursor,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentScanVersion.present) {
      map['current_scan_version'] = Variable<int>(currentScanVersion.value);
    }
    if (itemsProcessed.present) {
      map['items_processed'] = Variable<int>(itemsProcessed.value);
    }
    if (itemsTotal.present) {
      map['items_total'] = Variable<int>(itemsTotal.value);
    }
    if (bytesProcessed.present) {
      map['bytes_processed'] = Variable<int>(bytesProcessed.value);
    }
    if (lastSeenGeneration.present) {
      map['last_seen_generation'] = Variable<int>(lastSeenGeneration.value);
    }
    if (lastModifiedCursor.present) {
      map['last_modified_cursor'] = Variable<int>(lastModifiedCursor.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanStateTableCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('currentScanVersion: $currentScanVersion, ')
          ..write('itemsProcessed: $itemsProcessed, ')
          ..write('itemsTotal: $itemsTotal, ')
          ..write('bytesProcessed: $bytesProcessed, ')
          ..write('lastSeenGeneration: $lastSeenGeneration, ')
          ..write('lastModifiedCursor: $lastModifiedCursor, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $ScanStateTableTable scanStateTable = $ScanStateTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaItems,
    scanStateTable,
  ];
}

typedef $$MediaItemsTableCreateCompanionBuilder = MediaItemsCompanion Function({
  Value<int> id,
  required String contentUri,
  required String mediaStoreId,
  required String mimeType,
  required String sourceApp,
  required String bucketName,
  required String displayName,
  required int sizeBytes,
  Value<int> width,
  Value<int> height,
  Value<int> durationMs,
  required int dateAddedSec,
  required int dateModifiedSec,
  required int scanVersion,
  Value<bool> isProtected,
});
typedef $$MediaItemsTableUpdateCompanionBuilder = MediaItemsCompanion Function({
  Value<int> id,
  Value<String> contentUri,
  Value<String> mediaStoreId,
  Value<String> mimeType,
  Value<String> sourceApp,
  Value<String> bucketName,
  Value<String> displayName,
  Value<int> sizeBytes,
  Value<int> width,
  Value<int> height,
  Value<int> durationMs,
  Value<int> dateAddedSec,
  Value<int> dateModifiedSec,
  Value<int> scanVersion,
  Value<bool> isProtected,
});

class $$MediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
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

  ColumnFilters<int> get dateAddedSec => $composableBuilder(
    column: $table.dateAddedSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateModifiedSec => $composableBuilder(
    column: $table.dateModifiedSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scanVersion => $composableBuilder(
    column: $table.scanVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApp => $composableBuilder(
    column: $table.sourceApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
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

  ColumnOrderings<int> get dateAddedSec => $composableBuilder(
    column: $table.dateAddedSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateModifiedSec => $composableBuilder(
    column: $table.dateModifiedSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scanVersion => $composableBuilder(
    column: $table.scanVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get sourceApp =>
      $composableBuilder(column: $table.sourceApp, builder: (column) => column);

  GeneratedColumn<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dateAddedSec => $composableBuilder(
    column: $table.dateAddedSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dateModifiedSec => $composableBuilder(
    column: $table.dateModifiedSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scanVersion => $composableBuilder(
    column: $table.scanVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => column,
  );
}

class $$MediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaItemsTable,
          MediaItem,
          $$MediaItemsTableFilterComposer,
          $$MediaItemsTableOrderingComposer,
          $$MediaItemsTableAnnotationComposer,
          $$MediaItemsTableCreateCompanionBuilder,
          $$MediaItemsTableUpdateCompanionBuilder,
          (
            MediaItem,
            BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItem>,
          ),
          MediaItem,
          PrefetchHooks Function()
        > {
  $$MediaItemsTableTableManager(_$AppDatabase db, $MediaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> contentUri = const Value.absent(),
                Value<String> mediaStoreId = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> sourceApp = const Value.absent(),
                Value<String> bucketName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> dateAddedSec = const Value.absent(),
                Value<int> dateModifiedSec = const Value.absent(),
                Value<int> scanVersion = const Value.absent(),
                Value<bool> isProtected = const Value.absent(),
              }) => MediaItemsCompanion(
                id: id,
                contentUri: contentUri,
                mediaStoreId: mediaStoreId,
                mimeType: mimeType,
                sourceApp: sourceApp,
                bucketName: bucketName,
                displayName: displayName,
                sizeBytes: sizeBytes,
                width: width,
                height: height,
                durationMs: durationMs,
                dateAddedSec: dateAddedSec,
                dateModifiedSec: dateModifiedSec,
                scanVersion: scanVersion,
                isProtected: isProtected,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String contentUri,
                required String mediaStoreId,
                required String mimeType,
                required String sourceApp,
                required String bucketName,
                required String displayName,
                required int sizeBytes,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required int dateAddedSec,
                required int dateModifiedSec,
                required int scanVersion,
                Value<bool> isProtected = const Value.absent(),
              }) => MediaItemsCompanion.insert(
                id: id,
                contentUri: contentUri,
                mediaStoreId: mediaStoreId,
                mimeType: mimeType,
                sourceApp: sourceApp,
                bucketName: bucketName,
                displayName: displayName,
                sizeBytes: sizeBytes,
                width: width,
                height: height,
                durationMs: durationMs,
                dateAddedSec: dateAddedSec,
                dateModifiedSec: dateModifiedSec,
                scanVersion: scanVersion,
                isProtected: isProtected,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaItemsTable, MediaItem>(table),
                  BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaItemsTable,
      MediaItem,
      $$MediaItemsTableFilterComposer,
      $$MediaItemsTableOrderingComposer,
      $$MediaItemsTableAnnotationComposer,
      $$MediaItemsTableCreateCompanionBuilder,
      $$MediaItemsTableUpdateCompanionBuilder,
      (MediaItem, BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItem>),
      MediaItem,
      PrefetchHooks Function()
    >;
typedef $$ScanStateTableTableCreateCompanionBuilder =
    ScanStateTableCompanion Function({
      Value<int> id,
      Value<String> status,
      Value<int> currentScanVersion,
      Value<int> itemsProcessed,
      Value<int> itemsTotal,
      Value<int> bytesProcessed,
      Value<int> lastSeenGeneration,
      Value<int> lastModifiedCursor,
      Value<int> startedAtMs,
      Value<String?> errorMessage,
    });
typedef $$ScanStateTableTableUpdateCompanionBuilder =
    ScanStateTableCompanion Function({
      Value<int> id,
      Value<String> status,
      Value<int> currentScanVersion,
      Value<int> itemsProcessed,
      Value<int> itemsTotal,
      Value<int> bytesProcessed,
      Value<int> lastSeenGeneration,
      Value<int> lastModifiedCursor,
      Value<int> startedAtMs,
      Value<String?> errorMessage,
    });

class $$ScanStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScanStateTableTable> {
  $$ScanStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentScanVersion => $composableBuilder(
    column: $table.currentScanVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemsProcessed => $composableBuilder(
    column: $table.itemsProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemsTotal => $composableBuilder(
    column: $table.itemsTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenGeneration => $composableBuilder(
    column: $table.lastSeenGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastModifiedCursor => $composableBuilder(
    column: $table.lastModifiedCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanStateTableTable> {
  $$ScanStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentScanVersion => $composableBuilder(
    column: $table.currentScanVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemsProcessed => $composableBuilder(
    column: $table.itemsProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemsTotal => $composableBuilder(
    column: $table.itemsTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenGeneration => $composableBuilder(
    column: $table.lastSeenGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastModifiedCursor => $composableBuilder(
    column: $table.lastModifiedCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanStateTableTable> {
  $$ScanStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get currentScanVersion => $composableBuilder(
    column: $table.currentScanVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemsProcessed => $composableBuilder(
    column: $table.itemsProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemsTotal => $composableBuilder(
    column: $table.itemsTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesProcessed => $composableBuilder(
    column: $table.bytesProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenGeneration => $composableBuilder(
    column: $table.lastSeenGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastModifiedCursor => $composableBuilder(
    column: $table.lastModifiedCursor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$ScanStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanStateTableTable,
          ScanStateTableData,
          $$ScanStateTableTableFilterComposer,
          $$ScanStateTableTableOrderingComposer,
          $$ScanStateTableTableAnnotationComposer,
          $$ScanStateTableTableCreateCompanionBuilder,
          $$ScanStateTableTableUpdateCompanionBuilder,
          (
            ScanStateTableData,
            BaseReferences<
              _$AppDatabase,
              $ScanStateTableTable,
              ScanStateTableData
            >,
          ),
          ScanStateTableData,
          PrefetchHooks Function()
        > {
  $$ScanStateTableTableTableManager(
    _$AppDatabase db,
    $ScanStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> currentScanVersion = const Value.absent(),
                Value<int> itemsProcessed = const Value.absent(),
                Value<int> itemsTotal = const Value.absent(),
                Value<int> bytesProcessed = const Value.absent(),
                Value<int> lastSeenGeneration = const Value.absent(),
                Value<int> lastModifiedCursor = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => ScanStateTableCompanion(
                id: id,
                status: status,
                currentScanVersion: currentScanVersion,
                itemsProcessed: itemsProcessed,
                itemsTotal: itemsTotal,
                bytesProcessed: bytesProcessed,
                lastSeenGeneration: lastSeenGeneration,
                lastModifiedCursor: lastModifiedCursor,
                startedAtMs: startedAtMs,
                errorMessage: errorMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> currentScanVersion = const Value.absent(),
                Value<int> itemsProcessed = const Value.absent(),
                Value<int> itemsTotal = const Value.absent(),
                Value<int> bytesProcessed = const Value.absent(),
                Value<int> lastSeenGeneration = const Value.absent(),
                Value<int> lastModifiedCursor = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => ScanStateTableCompanion.insert(
                id: id,
                status: status,
                currentScanVersion: currentScanVersion,
                itemsProcessed: itemsProcessed,
                itemsTotal: itemsTotal,
                bytesProcessed: bytesProcessed,
                lastSeenGeneration: lastSeenGeneration,
                lastModifiedCursor: lastModifiedCursor,
                startedAtMs: startedAtMs,
                errorMessage: errorMessage,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanStateTableTable, ScanStateTableData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScanStateTableTable,
                    ScanStateTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanStateTableTable,
      ScanStateTableData,
      $$ScanStateTableTableFilterComposer,
      $$ScanStateTableTableOrderingComposer,
      $$ScanStateTableTableAnnotationComposer,
      $$ScanStateTableTableCreateCompanionBuilder,
      $$ScanStateTableTableUpdateCompanionBuilder,
      (
        ScanStateTableData,
        BaseReferences<_$AppDatabase, $ScanStateTableTable, ScanStateTableData>,
      ),
      ScanStateTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$ScanStateTableTableTableManager get scanStateTable =>
      $$ScanStateTableTableTableManager(_db, _db.scanStateTable);
}
