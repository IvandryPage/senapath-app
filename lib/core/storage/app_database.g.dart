// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final String key;
  final String value;
  const AppPreference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppPreference copyWith({String? key, String? value}) =>
      AppPreference(key: key ?? this.key, value: value ?? this.value);
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideSessionsTable extends RideSessions
    with TableInfo<$RideSessionsTable, RideSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ride'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('recorded'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedAtMeta = const VerificationMeta(
    'pausedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pausedAt = GeneratedColumn<DateTime>(
    'paused_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPausedMillisecondsMeta =
      const VerificationMeta('totalPausedMilliseconds');
  @override
  late final GeneratedColumn<int> totalPausedMilliseconds =
      GeneratedColumn<int>(
        'total_paused_milliseconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentSpeedMetersPerSecondMeta =
      const VerificationMeta('currentSpeedMetersPerSecond');
  @override
  late final GeneratedColumn<double> currentSpeedMetersPerSecond =
      GeneratedColumn<double>(
        'current_speed_meters_per_second',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _gpsAccuracyMetersMeta = const VerificationMeta(
    'gpsAccuracyMeters',
  );
  @override
  late final GeneratedColumn<double> gpsAccuracyMeters =
      GeneratedColumn<double>(
        'gps_accuracy_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    activityType,
    source,
    startedAt,
    endedAt,
    pausedAt,
    totalPausedMilliseconds,
    status,
    syncStatus,
    distanceMeters,
    currentSpeedMetersPerSecond,
    gpsAccuracyMeters,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('paused_at')) {
      context.handle(
        _pausedAtMeta,
        pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta),
      );
    }
    if (data.containsKey('total_paused_milliseconds')) {
      context.handle(
        _totalPausedMillisecondsMeta,
        totalPausedMilliseconds.isAcceptableOrUnknown(
          data['total_paused_milliseconds']!,
          _totalPausedMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('current_speed_meters_per_second')) {
      context.handle(
        _currentSpeedMetersPerSecondMeta,
        currentSpeedMetersPerSecond.isAcceptableOrUnknown(
          data['current_speed_meters_per_second']!,
          _currentSpeedMetersPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('gps_accuracy_meters')) {
      context.handle(
        _gpsAccuracyMetersMeta,
        gpsAccuracyMeters.isAcceptableOrUnknown(
          data['gps_accuracy_meters']!,
          _gpsAccuracyMetersMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RideSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      pausedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paused_at'],
      ),
      totalPausedMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_paused_milliseconds'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      )!,
      currentSpeedMetersPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_speed_meters_per_second'],
      )!,
      gpsAccuracyMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_accuracy_meters'],
      ),
    );
  }

  @override
  $RideSessionsTable createAlias(String alias) {
    return $RideSessionsTable(attachedDatabase, alias);
  }
}

class RideSession extends DataClass implements Insertable<RideSession> {
  final String id;
  final String title;
  final String activityType;
  final String source;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? pausedAt;
  final int totalPausedMilliseconds;
  final String status;
  final String syncStatus;
  final double distanceMeters;
  final double currentSpeedMetersPerSecond;
  final double? gpsAccuracyMeters;
  const RideSession({
    required this.id,
    required this.title,
    required this.activityType,
    required this.source,
    required this.startedAt,
    this.endedAt,
    this.pausedAt,
    required this.totalPausedMilliseconds,
    required this.status,
    required this.syncStatus,
    required this.distanceMeters,
    required this.currentSpeedMetersPerSecond,
    this.gpsAccuracyMeters,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['activity_type'] = Variable<String>(activityType);
    map['source'] = Variable<String>(source);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<DateTime>(pausedAt);
    }
    map['total_paused_milliseconds'] = Variable<int>(totalPausedMilliseconds);
    map['status'] = Variable<String>(status);
    map['sync_status'] = Variable<String>(syncStatus);
    map['distance_meters'] = Variable<double>(distanceMeters);
    map['current_speed_meters_per_second'] = Variable<double>(
      currentSpeedMetersPerSecond,
    );
    if (!nullToAbsent || gpsAccuracyMeters != null) {
      map['gps_accuracy_meters'] = Variable<double>(gpsAccuracyMeters);
    }
    return map;
  }

  RideSessionsCompanion toCompanion(bool nullToAbsent) {
    return RideSessionsCompanion(
      id: Value(id),
      title: Value(title),
      activityType: Value(activityType),
      source: Value(source),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      totalPausedMilliseconds: Value(totalPausedMilliseconds),
      status: Value(status),
      syncStatus: Value(syncStatus),
      distanceMeters: Value(distanceMeters),
      currentSpeedMetersPerSecond: Value(currentSpeedMetersPerSecond),
      gpsAccuracyMeters: gpsAccuracyMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsAccuracyMeters),
    );
  }

  factory RideSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideSession(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      activityType: serializer.fromJson<String>(json['activityType']),
      source: serializer.fromJson<String>(json['source']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      pausedAt: serializer.fromJson<DateTime?>(json['pausedAt']),
      totalPausedMilliseconds: serializer.fromJson<int>(
        json['totalPausedMilliseconds'],
      ),
      status: serializer.fromJson<String>(json['status']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      distanceMeters: serializer.fromJson<double>(json['distanceMeters']),
      currentSpeedMetersPerSecond: serializer.fromJson<double>(
        json['currentSpeedMetersPerSecond'],
      ),
      gpsAccuracyMeters: serializer.fromJson<double?>(
        json['gpsAccuracyMeters'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'activityType': serializer.toJson<String>(activityType),
      'source': serializer.toJson<String>(source),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'pausedAt': serializer.toJson<DateTime?>(pausedAt),
      'totalPausedMilliseconds': serializer.toJson<int>(
        totalPausedMilliseconds,
      ),
      'status': serializer.toJson<String>(status),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'distanceMeters': serializer.toJson<double>(distanceMeters),
      'currentSpeedMetersPerSecond': serializer.toJson<double>(
        currentSpeedMetersPerSecond,
      ),
      'gpsAccuracyMeters': serializer.toJson<double?>(gpsAccuracyMeters),
    };
  }

  RideSession copyWith({
    String? id,
    String? title,
    String? activityType,
    String? source,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<DateTime?> pausedAt = const Value.absent(),
    int? totalPausedMilliseconds,
    String? status,
    String? syncStatus,
    double? distanceMeters,
    double? currentSpeedMetersPerSecond,
    Value<double?> gpsAccuracyMeters = const Value.absent(),
  }) => RideSession(
    id: id ?? this.id,
    title: title ?? this.title,
    activityType: activityType ?? this.activityType,
    source: source ?? this.source,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
    totalPausedMilliseconds:
        totalPausedMilliseconds ?? this.totalPausedMilliseconds,
    status: status ?? this.status,
    syncStatus: syncStatus ?? this.syncStatus,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    currentSpeedMetersPerSecond:
        currentSpeedMetersPerSecond ?? this.currentSpeedMetersPerSecond,
    gpsAccuracyMeters: gpsAccuracyMeters.present
        ? gpsAccuracyMeters.value
        : this.gpsAccuracyMeters,
  );
  RideSession copyWithCompanion(RideSessionsCompanion data) {
    return RideSession(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      source: data.source.present ? data.source.value : this.source,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      totalPausedMilliseconds: data.totalPausedMilliseconds.present
          ? data.totalPausedMilliseconds.value
          : this.totalPausedMilliseconds,
      status: data.status.present ? data.status.value : this.status,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      currentSpeedMetersPerSecond: data.currentSpeedMetersPerSecond.present
          ? data.currentSpeedMetersPerSecond.value
          : this.currentSpeedMetersPerSecond,
      gpsAccuracyMeters: data.gpsAccuracyMeters.present
          ? data.gpsAccuracyMeters.value
          : this.gpsAccuracyMeters,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideSession(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('activityType: $activityType, ')
          ..write('source: $source, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('totalPausedMilliseconds: $totalPausedMilliseconds, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('currentSpeedMetersPerSecond: $currentSpeedMetersPerSecond, ')
          ..write('gpsAccuracyMeters: $gpsAccuracyMeters')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    activityType,
    source,
    startedAt,
    endedAt,
    pausedAt,
    totalPausedMilliseconds,
    status,
    syncStatus,
    distanceMeters,
    currentSpeedMetersPerSecond,
    gpsAccuracyMeters,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideSession &&
          other.id == this.id &&
          other.title == this.title &&
          other.activityType == this.activityType &&
          other.source == this.source &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pausedAt == this.pausedAt &&
          other.totalPausedMilliseconds == this.totalPausedMilliseconds &&
          other.status == this.status &&
          other.syncStatus == this.syncStatus &&
          other.distanceMeters == this.distanceMeters &&
          other.currentSpeedMetersPerSecond ==
              this.currentSpeedMetersPerSecond &&
          other.gpsAccuracyMeters == this.gpsAccuracyMeters);
}

class RideSessionsCompanion extends UpdateCompanion<RideSession> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> activityType;
  final Value<String> source;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<DateTime?> pausedAt;
  final Value<int> totalPausedMilliseconds;
  final Value<String> status;
  final Value<String> syncStatus;
  final Value<double> distanceMeters;
  final Value<double> currentSpeedMetersPerSecond;
  final Value<double?> gpsAccuracyMeters;
  final Value<int> rowid;
  const RideSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.activityType = const Value.absent(),
    this.source = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.totalPausedMilliseconds = const Value.absent(),
    this.status = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.currentSpeedMetersPerSecond = const Value.absent(),
    this.gpsAccuracyMeters = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideSessionsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.activityType = const Value.absent(),
    this.source = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.totalPausedMilliseconds = const Value.absent(),
    required String status,
    this.syncStatus = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.currentSpeedMetersPerSecond = const Value.absent(),
    this.gpsAccuracyMeters = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       status = Value(status);
  static Insertable<RideSession> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? activityType,
    Expression<String>? source,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<DateTime>? pausedAt,
    Expression<int>? totalPausedMilliseconds,
    Expression<String>? status,
    Expression<String>? syncStatus,
    Expression<double>? distanceMeters,
    Expression<double>? currentSpeedMetersPerSecond,
    Expression<double>? gpsAccuracyMeters,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (activityType != null) 'activity_type': activityType,
      if (source != null) 'source': source,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (totalPausedMilliseconds != null)
        'total_paused_milliseconds': totalPausedMilliseconds,
      if (status != null) 'status': status,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (currentSpeedMetersPerSecond != null)
        'current_speed_meters_per_second': currentSpeedMetersPerSecond,
      if (gpsAccuracyMeters != null) 'gps_accuracy_meters': gpsAccuracyMeters,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? activityType,
    Value<String>? source,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<DateTime?>? pausedAt,
    Value<int>? totalPausedMilliseconds,
    Value<String>? status,
    Value<String>? syncStatus,
    Value<double>? distanceMeters,
    Value<double>? currentSpeedMetersPerSecond,
    Value<double?>? gpsAccuracyMeters,
    Value<int>? rowid,
  }) {
    return RideSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      activityType: activityType ?? this.activityType,
      source: source ?? this.source,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedMilliseconds:
          totalPausedMilliseconds ?? this.totalPausedMilliseconds,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeedMetersPerSecond:
          currentSpeedMetersPerSecond ?? this.currentSpeedMetersPerSecond,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<DateTime>(pausedAt.value);
    }
    if (totalPausedMilliseconds.present) {
      map['total_paused_milliseconds'] = Variable<int>(
        totalPausedMilliseconds.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (currentSpeedMetersPerSecond.present) {
      map['current_speed_meters_per_second'] = Variable<double>(
        currentSpeedMetersPerSecond.value,
      );
    }
    if (gpsAccuracyMeters.present) {
      map['gps_accuracy_meters'] = Variable<double>(gpsAccuracyMeters.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('activityType: $activityType, ')
          ..write('source: $source, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('totalPausedMilliseconds: $totalPausedMilliseconds, ')
          ..write('status: $status, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('currentSpeedMetersPerSecond: $currentSpeedMetersPerSecond, ')
          ..write('gpsAccuracyMeters: $gpsAccuracyMeters, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TelemetryPointsTable extends TelemetryPoints
    with TableInfo<$TelemetryPointsTable, TelemetryPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TelemetryPointsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ride_sessions (id)',
    ),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedPayload =
      GeneratedColumn<Uint8List>(
        'encrypted_payload',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    recordedAt,
    encryptedPayload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'telemetry_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TelemetryPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TelemetryPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TelemetryPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_payload'],
      )!,
    );
  }

  @override
  $TelemetryPointsTable createAlias(String alias) {
    return $TelemetryPointsTable(attachedDatabase, alias);
  }
}

class TelemetryPoint extends DataClass implements Insertable<TelemetryPoint> {
  final int id;
  final String sessionId;
  final DateTime recordedAt;
  final Uint8List encryptedPayload;
  const TelemetryPoint({
    required this.id,
    required this.sessionId,
    required this.recordedAt,
    required this.encryptedPayload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload);
    return map;
  }

  TelemetryPointsCompanion toCompanion(bool nullToAbsent) {
    return TelemetryPointsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      recordedAt: Value(recordedAt),
      encryptedPayload: Value(encryptedPayload),
    );
  }

  factory TelemetryPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TelemetryPoint(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      encryptedPayload: serializer.fromJson<Uint8List>(
        json['encryptedPayload'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'encryptedPayload': serializer.toJson<Uint8List>(encryptedPayload),
    };
  }

  TelemetryPoint copyWith({
    int? id,
    String? sessionId,
    DateTime? recordedAt,
    Uint8List? encryptedPayload,
  }) => TelemetryPoint(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    recordedAt: recordedAt ?? this.recordedAt,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
  );
  TelemetryPoint copyWithCompanion(TelemetryPointsCompanion data) {
    return TelemetryPoint(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TelemetryPoint(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('encryptedPayload: $encryptedPayload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    recordedAt,
    $driftBlobEquality.hash(encryptedPayload),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TelemetryPoint &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.recordedAt == this.recordedAt &&
          $driftBlobEquality.equals(
            other.encryptedPayload,
            this.encryptedPayload,
          ));
}

class TelemetryPointsCompanion extends UpdateCompanion<TelemetryPoint> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> recordedAt;
  final Value<Uint8List> encryptedPayload;
  const TelemetryPointsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
  });
  TelemetryPointsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime recordedAt,
    required Uint8List encryptedPayload,
  }) : sessionId = Value(sessionId),
       recordedAt = Value(recordedAt),
       encryptedPayload = Value(encryptedPayload);
  static Insertable<TelemetryPoint> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? recordedAt,
    Expression<Uint8List>? encryptedPayload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
    });
  }

  TelemetryPointsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? recordedAt,
    Value<Uint8List>? encryptedPayload,
  }) {
    return TelemetryPointsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      recordedAt: recordedAt ?? this.recordedAt,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<Uint8List>(encryptedPayload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TelemetryPointsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('encryptedPayload: $encryptedPayload')
          ..write(')'))
        .toString();
  }
}

class $SavedRoutesTable extends SavedRoutes
    with TableInfo<$SavedRoutesTable, SavedRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationGainMetersMeta =
      const VerificationMeta('elevationGainMeters');
  @override
  late final GeneratedColumn<double> elevationGainMeters =
      GeneratedColumn<double>(
        'elevation_gain_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _poiSummaryMeta = const VerificationMeta(
    'poiSummary',
  );
  @override
  late final GeneratedColumn<String> poiSummary = GeneratedColumn<String>(
    'poi_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('offline'),
  );
  static const VerificationMeta _encryptedGeometryMeta = const VerificationMeta(
    'encryptedGeometry',
  );
  @override
  late final GeneratedColumn<Uint8List> encryptedGeometry =
      GeneratedColumn<Uint8List>(
        'encrypted_geometry',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    source,
    description,
    updatedAt,
    distanceMeters,
    elevationGainMeters,
    poiSummary,
    availability,
    encryptedGeometry,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('elevation_gain_meters')) {
      context.handle(
        _elevationGainMetersMeta,
        elevationGainMeters.isAcceptableOrUnknown(
          data['elevation_gain_meters']!,
          _elevationGainMetersMeta,
        ),
      );
    }
    if (data.containsKey('poi_summary')) {
      context.handle(
        _poiSummaryMeta,
        poiSummary.isAcceptableOrUnknown(data['poi_summary']!, _poiSummaryMeta),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_geometry')) {
      context.handle(
        _encryptedGeometryMeta,
        encryptedGeometry.isAcceptableOrUnknown(
          data['encrypted_geometry']!,
          _encryptedGeometryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedRoute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      ),
      elevationGainMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_gain_meters'],
      ),
      poiSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_summary'],
      )!,
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
      encryptedGeometry: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}encrypted_geometry'],
      ),
    );
  }

  @override
  $SavedRoutesTable createAlias(String alias) {
    return $SavedRoutesTable(attachedDatabase, alias);
  }
}

class SavedRoute extends DataClass implements Insertable<SavedRoute> {
  final String id;
  final String name;
  final String source;
  final String description;
  final DateTime updatedAt;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final String poiSummary;
  final String availability;
  final Uint8List? encryptedGeometry;
  const SavedRoute({
    required this.id,
    required this.name,
    required this.source,
    required this.description,
    required this.updatedAt,
    this.distanceMeters,
    this.elevationGainMeters,
    required this.poiSummary,
    required this.availability,
    this.encryptedGeometry,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['source'] = Variable<String>(source);
    map['description'] = Variable<String>(description);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    if (!nullToAbsent || elevationGainMeters != null) {
      map['elevation_gain_meters'] = Variable<double>(elevationGainMeters);
    }
    map['poi_summary'] = Variable<String>(poiSummary);
    map['availability'] = Variable<String>(availability);
    if (!nullToAbsent || encryptedGeometry != null) {
      map['encrypted_geometry'] = Variable<Uint8List>(encryptedGeometry);
    }
    return map;
  }

  SavedRoutesCompanion toCompanion(bool nullToAbsent) {
    return SavedRoutesCompanion(
      id: Value(id),
      name: Value(name),
      source: Value(source),
      description: Value(description),
      updatedAt: Value(updatedAt),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      elevationGainMeters: elevationGainMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationGainMeters),
      poiSummary: Value(poiSummary),
      availability: Value(availability),
      encryptedGeometry: encryptedGeometry == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedGeometry),
    );
  }

  factory SavedRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedRoute(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      source: serializer.fromJson<String>(json['source']),
      description: serializer.fromJson<String>(json['description']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      elevationGainMeters: serializer.fromJson<double?>(
        json['elevationGainMeters'],
      ),
      poiSummary: serializer.fromJson<String>(json['poiSummary']),
      availability: serializer.fromJson<String>(json['availability']),
      encryptedGeometry: serializer.fromJson<Uint8List?>(
        json['encryptedGeometry'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'source': serializer.toJson<String>(source),
      'description': serializer.toJson<String>(description),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'elevationGainMeters': serializer.toJson<double?>(elevationGainMeters),
      'poiSummary': serializer.toJson<String>(poiSummary),
      'availability': serializer.toJson<String>(availability),
      'encryptedGeometry': serializer.toJson<Uint8List?>(encryptedGeometry),
    };
  }

  SavedRoute copyWith({
    String? id,
    String? name,
    String? source,
    String? description,
    DateTime? updatedAt,
    Value<double?> distanceMeters = const Value.absent(),
    Value<double?> elevationGainMeters = const Value.absent(),
    String? poiSummary,
    String? availability,
    Value<Uint8List?> encryptedGeometry = const Value.absent(),
  }) => SavedRoute(
    id: id ?? this.id,
    name: name ?? this.name,
    source: source ?? this.source,
    description: description ?? this.description,
    updatedAt: updatedAt ?? this.updatedAt,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    elevationGainMeters: elevationGainMeters.present
        ? elevationGainMeters.value
        : this.elevationGainMeters,
    poiSummary: poiSummary ?? this.poiSummary,
    availability: availability ?? this.availability,
    encryptedGeometry: encryptedGeometry.present
        ? encryptedGeometry.value
        : this.encryptedGeometry,
  );
  SavedRoute copyWithCompanion(SavedRoutesCompanion data) {
    return SavedRoute(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      description: data.description.present
          ? data.description.value
          : this.description,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      elevationGainMeters: data.elevationGainMeters.present
          ? data.elevationGainMeters.value
          : this.elevationGainMeters,
      poiSummary: data.poiSummary.present
          ? data.poiSummary.value
          : this.poiSummary,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      encryptedGeometry: data.encryptedGeometry.present
          ? data.encryptedGeometry.value
          : this.encryptedGeometry,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedRoute(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('description: $description, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('elevationGainMeters: $elevationGainMeters, ')
          ..write('poiSummary: $poiSummary, ')
          ..write('availability: $availability, ')
          ..write('encryptedGeometry: $encryptedGeometry')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    source,
    description,
    updatedAt,
    distanceMeters,
    elevationGainMeters,
    poiSummary,
    availability,
    $driftBlobEquality.hash(encryptedGeometry),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedRoute &&
          other.id == this.id &&
          other.name == this.name &&
          other.source == this.source &&
          other.description == this.description &&
          other.updatedAt == this.updatedAt &&
          other.distanceMeters == this.distanceMeters &&
          other.elevationGainMeters == this.elevationGainMeters &&
          other.poiSummary == this.poiSummary &&
          other.availability == this.availability &&
          $driftBlobEquality.equals(
            other.encryptedGeometry,
            this.encryptedGeometry,
          ));
}

class SavedRoutesCompanion extends UpdateCompanion<SavedRoute> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> source;
  final Value<String> description;
  final Value<DateTime> updatedAt;
  final Value<double?> distanceMeters;
  final Value<double?> elevationGainMeters;
  final Value<String> poiSummary;
  final Value<String> availability;
  final Value<Uint8List?> encryptedGeometry;
  final Value<int> rowid;
  const SavedRoutesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.description = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.elevationGainMeters = const Value.absent(),
    this.poiSummary = const Value.absent(),
    this.availability = const Value.absent(),
    this.encryptedGeometry = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedRoutesCompanion.insert({
    required String id,
    required String name,
    required String source,
    this.description = const Value.absent(),
    required DateTime updatedAt,
    this.distanceMeters = const Value.absent(),
    this.elevationGainMeters = const Value.absent(),
    this.poiSummary = const Value.absent(),
    this.availability = const Value.absent(),
    this.encryptedGeometry = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       source = Value(source),
       updatedAt = Value(updatedAt);
  static Insertable<SavedRoute> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? source,
    Expression<String>? description,
    Expression<DateTime>? updatedAt,
    Expression<double>? distanceMeters,
    Expression<double>? elevationGainMeters,
    Expression<String>? poiSummary,
    Expression<String>? availability,
    Expression<Uint8List>? encryptedGeometry,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (description != null) 'description': description,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (elevationGainMeters != null)
        'elevation_gain_meters': elevationGainMeters,
      if (poiSummary != null) 'poi_summary': poiSummary,
      if (availability != null) 'availability': availability,
      if (encryptedGeometry != null) 'encrypted_geometry': encryptedGeometry,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedRoutesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? source,
    Value<String>? description,
    Value<DateTime>? updatedAt,
    Value<double?>? distanceMeters,
    Value<double?>? elevationGainMeters,
    Value<String>? poiSummary,
    Value<String>? availability,
    Value<Uint8List?>? encryptedGeometry,
    Value<int>? rowid,
  }) {
    return SavedRoutesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      poiSummary: poiSummary ?? this.poiSummary,
      availability: availability ?? this.availability,
      encryptedGeometry: encryptedGeometry ?? this.encryptedGeometry,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (elevationGainMeters.present) {
      map['elevation_gain_meters'] = Variable<double>(
        elevationGainMeters.value,
      );
    }
    if (poiSummary.present) {
      map['poi_summary'] = Variable<String>(poiSummary.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (encryptedGeometry.present) {
      map['encrypted_geometry'] = Variable<Uint8List>(encryptedGeometry.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedRoutesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('description: $description, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('elevationGainMeters: $elevationGainMeters, ')
          ..write('poiSummary: $poiSummary, ')
          ..write('availability: $availability, ')
          ..write('encryptedGeometry: $encryptedGeometry, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $RideSessionsTable rideSessions = $RideSessionsTable(this);
  late final $TelemetryPointsTable telemetryPoints = $TelemetryPointsTable(
    this,
  );
  late final $SavedRoutesTable savedRoutes = $SavedRoutesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appPreferences,
    rideSessions,
    telemetryPoints,
    savedRoutes,
  ];
}

typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreference,
            BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
          ),
          AppPreference,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppPreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppPreferencesTable, AppPreference>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppPreferencesTable,
                    AppPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreference,
        BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
      ),
      AppPreference,
      PrefetchHooks Function()
    >;
typedef $$RideSessionsTableCreateCompanionBuilder =
    RideSessionsCompanion Function({
      required String id,
      Value<String> title,
      Value<String> activityType,
      Value<String> source,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<DateTime?> pausedAt,
      Value<int> totalPausedMilliseconds,
      required String status,
      Value<String> syncStatus,
      Value<double> distanceMeters,
      Value<double> currentSpeedMetersPerSecond,
      Value<double?> gpsAccuracyMeters,
      Value<int> rowid,
    });
typedef $$RideSessionsTableUpdateCompanionBuilder =
    RideSessionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> activityType,
      Value<String> source,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<DateTime?> pausedAt,
      Value<int> totalPausedMilliseconds,
      Value<String> status,
      Value<String> syncStatus,
      Value<double> distanceMeters,
      Value<double> currentSpeedMetersPerSecond,
      Value<double?> gpsAccuracyMeters,
      Value<int> rowid,
    });

final class $$RideSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $RideSessionsTable, RideSession> {
  $$RideSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TelemetryPointsTable, List<TelemetryPoint>>
  _telemetryPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.telemetryPoints,
    aliasName: 'ride_sessions__id__telemetry_points__session_id',
  );

  $$TelemetryPointsTableProcessedTableManager get telemetryPointsRefs {
    final manager = $$TelemetryPointsTableTableManager(
      $_db,
      $_db.telemetryPoints,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _telemetryPointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RideSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $RideSessionsTable> {
  $$RideSessionsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPausedMilliseconds => $composableBuilder(
    column: $table.totalPausedMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentSpeedMetersPerSecond => $composableBuilder(
    column: $table.currentSpeedMetersPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsAccuracyMeters => $composableBuilder(
    column: $table.gpsAccuracyMeters,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> telemetryPointsRefs(
    Expression<bool> Function($$TelemetryPointsTableFilterComposer f) f,
  ) {
    final $$TelemetryPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.telemetryPoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TelemetryPointsTableFilterComposer(
            $db: $db,
            $table: $db.telemetryPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RideSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RideSessionsTable> {
  $$RideSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPausedMilliseconds => $composableBuilder(
    column: $table.totalPausedMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentSpeedMetersPerSecond => $composableBuilder(
    column: $table.currentSpeedMetersPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsAccuracyMeters => $composableBuilder(
    column: $table.gpsAccuracyMeters,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RideSessionsTable> {
  $$RideSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get totalPausedMilliseconds => $composableBuilder(
    column: $table.totalPausedMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentSpeedMetersPerSecond => $composableBuilder(
    column: $table.currentSpeedMetersPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gpsAccuracyMeters => $composableBuilder(
    column: $table.gpsAccuracyMeters,
    builder: (column) => column,
  );

  Expression<T> telemetryPointsRefs<T extends Object>(
    Expression<T> Function($$TelemetryPointsTableAnnotationComposer a) f,
  ) {
    final $$TelemetryPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.telemetryPoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TelemetryPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.telemetryPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RideSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RideSessionsTable,
          RideSession,
          $$RideSessionsTableFilterComposer,
          $$RideSessionsTableOrderingComposer,
          $$RideSessionsTableAnnotationComposer,
          $$RideSessionsTableCreateCompanionBuilder,
          $$RideSessionsTableUpdateCompanionBuilder,
          (RideSession, $$RideSessionsTableReferences),
          RideSession,
          PrefetchHooks Function({bool telemetryPointsRefs})
        > {
  $$RideSessionsTableTableManager(_$AppDatabase db, $RideSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> activityType = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> totalPausedMilliseconds = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<double> distanceMeters = const Value.absent(),
                Value<double> currentSpeedMetersPerSecond =
                    const Value.absent(),
                Value<double?> gpsAccuracyMeters = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideSessionsCompanion(
                id: id,
                title: title,
                activityType: activityType,
                source: source,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedAt: pausedAt,
                totalPausedMilliseconds: totalPausedMilliseconds,
                status: status,
                syncStatus: syncStatus,
                distanceMeters: distanceMeters,
                currentSpeedMetersPerSecond: currentSpeedMetersPerSecond,
                gpsAccuracyMeters: gpsAccuracyMeters,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> activityType = const Value.absent(),
                Value<String> source = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<int> totalPausedMilliseconds = const Value.absent(),
                required String status,
                Value<String> syncStatus = const Value.absent(),
                Value<double> distanceMeters = const Value.absent(),
                Value<double> currentSpeedMetersPerSecond =
                    const Value.absent(),
                Value<double?> gpsAccuracyMeters = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideSessionsCompanion.insert(
                id: id,
                title: title,
                activityType: activityType,
                source: source,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedAt: pausedAt,
                totalPausedMilliseconds: totalPausedMilliseconds,
                status: status,
                syncStatus: syncStatus,
                distanceMeters: distanceMeters,
                currentSpeedMetersPerSecond: currentSpeedMetersPerSecond,
                gpsAccuracyMeters: gpsAccuracyMeters,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideSessionsTable, RideSession>(table),
                  $$RideSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({telemetryPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (telemetryPointsRefs) db.telemetryPoints,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (telemetryPointsRefs)
                    await $_getPrefetchedData<
                      RideSession,
                      $RideSessionsTable,
                      TelemetryPoint
                    >(
                      currentTable: table,
                      referencedTable: $$RideSessionsTableReferences
                          ._telemetryPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RideSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).telemetryPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RideSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RideSessionsTable,
      RideSession,
      $$RideSessionsTableFilterComposer,
      $$RideSessionsTableOrderingComposer,
      $$RideSessionsTableAnnotationComposer,
      $$RideSessionsTableCreateCompanionBuilder,
      $$RideSessionsTableUpdateCompanionBuilder,
      (RideSession, $$RideSessionsTableReferences),
      RideSession,
      PrefetchHooks Function({bool telemetryPointsRefs})
    >;
typedef $$TelemetryPointsTableCreateCompanionBuilder =
    TelemetryPointsCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime recordedAt,
      required Uint8List encryptedPayload,
    });
typedef $$TelemetryPointsTableUpdateCompanionBuilder =
    TelemetryPointsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> recordedAt,
      Value<Uint8List> encryptedPayload,
    });

final class $$TelemetryPointsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TelemetryPointsTable, TelemetryPoint> {
  $$TelemetryPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RideSessionsTable _sessionIdTable(_$AppDatabase db) => db.rideSessions
      .createAlias('telemetry_points__session_id__ride_sessions__id');

  $$RideSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$RideSessionsTableTableManager(
      $_db,
      $_db.rideSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TelemetryPointsTableFilterComposer
    extends Composer<_$AppDatabase, $TelemetryPointsTable> {
  $$TelemetryPointsTableFilterComposer({
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

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  $$RideSessionsTableFilterComposer get sessionId {
    final $$RideSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.rideSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RideSessionsTableFilterComposer(
            $db: $db,
            $table: $db.rideSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetryPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TelemetryPointsTable> {
  $$TelemetryPointsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  $$RideSessionsTableOrderingComposer get sessionId {
    final $$RideSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.rideSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RideSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.rideSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetryPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TelemetryPointsTable> {
  $$TelemetryPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  $$RideSessionsTableAnnotationComposer get sessionId {
    final $$RideSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.rideSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RideSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.rideSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TelemetryPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TelemetryPointsTable,
          TelemetryPoint,
          $$TelemetryPointsTableFilterComposer,
          $$TelemetryPointsTableOrderingComposer,
          $$TelemetryPointsTableAnnotationComposer,
          $$TelemetryPointsTableCreateCompanionBuilder,
          $$TelemetryPointsTableUpdateCompanionBuilder,
          (TelemetryPoint, $$TelemetryPointsTableReferences),
          TelemetryPoint,
          PrefetchHooks Function({bool sessionId})
        > {
  $$TelemetryPointsTableTableManager(
    _$AppDatabase db,
    $TelemetryPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TelemetryPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TelemetryPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TelemetryPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<Uint8List> encryptedPayload = const Value.absent(),
              }) => TelemetryPointsCompanion(
                id: id,
                sessionId: sessionId,
                recordedAt: recordedAt,
                encryptedPayload: encryptedPayload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime recordedAt,
                required Uint8List encryptedPayload,
              }) => TelemetryPointsCompanion.insert(
                id: id,
                sessionId: sessionId,
                recordedAt: recordedAt,
                encryptedPayload: encryptedPayload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TelemetryPointsTable, TelemetryPoint>(table),
                  $$TelemetryPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$TelemetryPointsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$TelemetryPointsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TelemetryPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TelemetryPointsTable,
      TelemetryPoint,
      $$TelemetryPointsTableFilterComposer,
      $$TelemetryPointsTableOrderingComposer,
      $$TelemetryPointsTableAnnotationComposer,
      $$TelemetryPointsTableCreateCompanionBuilder,
      $$TelemetryPointsTableUpdateCompanionBuilder,
      (TelemetryPoint, $$TelemetryPointsTableReferences),
      TelemetryPoint,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SavedRoutesTableCreateCompanionBuilder =
    SavedRoutesCompanion Function({
      required String id,
      required String name,
      required String source,
      Value<String> description,
      required DateTime updatedAt,
      Value<double?> distanceMeters,
      Value<double?> elevationGainMeters,
      Value<String> poiSummary,
      Value<String> availability,
      Value<Uint8List?> encryptedGeometry,
      Value<int> rowid,
    });
typedef $$SavedRoutesTableUpdateCompanionBuilder =
    SavedRoutesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> source,
      Value<String> description,
      Value<DateTime> updatedAt,
      Value<double?> distanceMeters,
      Value<double?> elevationGainMeters,
      Value<String> poiSummary,
      Value<String> availability,
      Value<Uint8List?> encryptedGeometry,
      Value<int> rowid,
    });

class $$SavedRoutesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedRoutesTable> {
  $$SavedRoutesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationGainMeters => $composableBuilder(
    column: $table.elevationGainMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poiSummary => $composableBuilder(
    column: $table.poiSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get encryptedGeometry => $composableBuilder(
    column: $table.encryptedGeometry,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedRoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedRoutesTable> {
  $$SavedRoutesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationGainMeters => $composableBuilder(
    column: $table.elevationGainMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poiSummary => $composableBuilder(
    column: $table.poiSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get encryptedGeometry => $composableBuilder(
    column: $table.encryptedGeometry,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedRoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedRoutesTable> {
  $$SavedRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get elevationGainMeters => $composableBuilder(
    column: $table.elevationGainMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get poiSummary => $composableBuilder(
    column: $table.poiSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get encryptedGeometry => $composableBuilder(
    column: $table.encryptedGeometry,
    builder: (column) => column,
  );
}

class $$SavedRoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedRoutesTable,
          SavedRoute,
          $$SavedRoutesTableFilterComposer,
          $$SavedRoutesTableOrderingComposer,
          $$SavedRoutesTableAnnotationComposer,
          $$SavedRoutesTableCreateCompanionBuilder,
          $$SavedRoutesTableUpdateCompanionBuilder,
          (
            SavedRoute,
            BaseReferences<_$AppDatabase, $SavedRoutesTable, SavedRoute>,
          ),
          SavedRoute,
          PrefetchHooks Function()
        > {
  $$SavedRoutesTableTableManager(_$AppDatabase db, $SavedRoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<double?> elevationGainMeters = const Value.absent(),
                Value<String> poiSummary = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<Uint8List?> encryptedGeometry = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedRoutesCompanion(
                id: id,
                name: name,
                source: source,
                description: description,
                updatedAt: updatedAt,
                distanceMeters: distanceMeters,
                elevationGainMeters: elevationGainMeters,
                poiSummary: poiSummary,
                availability: availability,
                encryptedGeometry: encryptedGeometry,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String source,
                Value<String> description = const Value.absent(),
                required DateTime updatedAt,
                Value<double?> distanceMeters = const Value.absent(),
                Value<double?> elevationGainMeters = const Value.absent(),
                Value<String> poiSummary = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<Uint8List?> encryptedGeometry = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedRoutesCompanion.insert(
                id: id,
                name: name,
                source: source,
                description: description,
                updatedAt: updatedAt,
                distanceMeters: distanceMeters,
                elevationGainMeters: elevationGainMeters,
                poiSummary: poiSummary,
                availability: availability,
                encryptedGeometry: encryptedGeometry,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedRoutesTable, SavedRoute>(table),
                  BaseReferences<_$AppDatabase, $SavedRoutesTable, SavedRoute>(
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

typedef $$SavedRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedRoutesTable,
      SavedRoute,
      $$SavedRoutesTableFilterComposer,
      $$SavedRoutesTableOrderingComposer,
      $$SavedRoutesTableAnnotationComposer,
      $$SavedRoutesTableCreateCompanionBuilder,
      $$SavedRoutesTableUpdateCompanionBuilder,
      (
        SavedRoute,
        BaseReferences<_$AppDatabase, $SavedRoutesTable, SavedRoute>,
      ),
      SavedRoute,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$RideSessionsTableTableManager get rideSessions =>
      $$RideSessionsTableTableManager(_db, _db.rideSessions);
  $$TelemetryPointsTableTableManager get telemetryPoints =>
      $$TelemetryPointsTableTableManager(_db, _db.telemetryPoints);
  $$SavedRoutesTableTableManager get savedRoutes =>
      $$SavedRoutesTableTableManager(_db, _db.savedRoutes);
}
