// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TaskRowsTable extends TaskRows with TableInfo<$TaskRowsTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerUserIdMeta =
      const VerificationMeta('ownerUserId');
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
      'owner_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('task'));
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _timezoneIdMeta =
      const VerificationMeta('timezoneId');
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
      'timezone_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _repeatRuleJsonMeta =
      const VerificationMeta('repeatRuleJson');
  @override
  late final GeneratedColumn<String> repeatRuleJson = GeneratedColumn<String>(
      'repeat_rule_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{"type":"none"}'));
  static const VerificationMeta _reminderMinutesMeta =
      const VerificationMeta('reminderMinutes');
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
      'reminder_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _reminderEnabledMeta =
      const VerificationMeta('reminderEnabled');
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
      'reminder_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("reminder_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('planned'));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ownerUserId,
        title,
        description,
        kind,
        location,
        startAt,
        endAt,
        timezoneId,
        repeatRuleJson,
        reminderMinutes,
        reminderEnabled,
        status,
        priority,
        version,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_rows';
  @override
  VerificationContext validateIntegrity(Insertable<TaskRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
          _ownerUserIdMeta,
          ownerUserId.isAcceptableOrUnknown(
              data['owner_user_id']!, _ownerUserIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
          _timezoneIdMeta,
          timezoneId.isAcceptableOrUnknown(
              data['timezone_id']!, _timezoneIdMeta));
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('repeat_rule_json')) {
      context.handle(
          _repeatRuleJsonMeta,
          repeatRuleJson.isAcceptableOrUnknown(
              data['repeat_rule_json']!, _repeatRuleJsonMeta));
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
          _reminderMinutesMeta,
          reminderMinutes.isAcceptableOrUnknown(
              data['reminder_minutes']!, _reminderMinutesMeta));
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
          _reminderEnabledMeta,
          reminderEnabled.isAcceptableOrUnknown(
              data['reminder_enabled']!, _reminderEnabledMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ownerUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_user_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at'])!,
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at'])!,
      timezoneId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timezone_id'])!,
      repeatRuleJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}repeat_rule_json'])!,
      reminderMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reminder_minutes'])!,
      reminderEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}reminder_enabled'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $TaskRowsTable createAlias(String alias) {
    return $TaskRowsTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final String? ownerUserId;
  final String title;
  final String description;
  final String kind;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String timezoneId;
  final String repeatRuleJson;
  final int reminderMinutes;
  final bool reminderEnabled;
  final String status;
  final int priority;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TaskRow(
      {required this.id,
      this.ownerUserId,
      required this.title,
      required this.description,
      required this.kind,
      required this.location,
      required this.startAt,
      required this.endAt,
      required this.timezoneId,
      required this.repeatRuleJson,
      required this.reminderMinutes,
      required this.reminderEnabled,
      required this.status,
      required this.priority,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['kind'] = Variable<String>(kind);
    map['location'] = Variable<String>(location);
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['timezone_id'] = Variable<String>(timezoneId);
    map['repeat_rule_json'] = Variable<String>(repeatRuleJson);
    map['reminder_minutes'] = Variable<int>(reminderMinutes);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TaskRowsCompanion toCompanion(bool nullToAbsent) {
    return TaskRowsCompanion(
      id: Value(id),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      title: Value(title),
      description: Value(description),
      kind: Value(kind),
      location: Value(location),
      startAt: Value(startAt),
      endAt: Value(endAt),
      timezoneId: Value(timezoneId),
      repeatRuleJson: Value(repeatRuleJson),
      reminderMinutes: Value(reminderMinutes),
      reminderEnabled: Value(reminderEnabled),
      status: Value(status),
      priority: Value(priority),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TaskRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      kind: serializer.fromJson<String>(json['kind']),
      location: serializer.fromJson<String>(json['location']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      repeatRuleJson: serializer.fromJson<String>(json['repeatRuleJson']),
      reminderMinutes: serializer.fromJson<int>(json['reminderMinutes']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'kind': serializer.toJson<String>(kind),
      'location': serializer.toJson<String>(location),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'repeatRuleJson': serializer.toJson<String>(repeatRuleJson),
      'reminderMinutes': serializer.toJson<int>(reminderMinutes),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TaskRow copyWith(
          {String? id,
          Value<String?> ownerUserId = const Value.absent(),
          String? title,
          String? description,
          String? kind,
          String? location,
          DateTime? startAt,
          DateTime? endAt,
          String? timezoneId,
          String? repeatRuleJson,
          int? reminderMinutes,
          bool? reminderEnabled,
          String? status,
          int? priority,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      TaskRow(
        id: id ?? this.id,
        ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
        title: title ?? this.title,
        description: description ?? this.description,
        kind: kind ?? this.kind,
        location: location ?? this.location,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        timezoneId: timezoneId ?? this.timezoneId,
        repeatRuleJson: repeatRuleJson ?? this.repeatRuleJson,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  TaskRow copyWithCompanion(TaskRowsCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      ownerUserId:
          data.ownerUserId.present ? data.ownerUserId.value : this.ownerUserId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      kind: data.kind.present ? data.kind.value : this.kind,
      location: data.location.present ? data.location.value : this.location,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      timezoneId:
          data.timezoneId.present ? data.timezoneId.value : this.timezoneId,
      repeatRuleJson: data.repeatRuleJson.present
          ? data.repeatRuleJson.value
          : this.repeatRuleJson,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('location: $location, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('repeatRuleJson: $repeatRuleJson, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ownerUserId,
      title,
      description,
      kind,
      location,
      startAt,
      endAt,
      timezoneId,
      repeatRuleJson,
      reminderMinutes,
      reminderEnabled,
      status,
      priority,
      version,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.ownerUserId == this.ownerUserId &&
          other.title == this.title &&
          other.description == this.description &&
          other.kind == this.kind &&
          other.location == this.location &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.timezoneId == this.timezoneId &&
          other.repeatRuleJson == this.repeatRuleJson &&
          other.reminderMinutes == this.reminderMinutes &&
          other.reminderEnabled == this.reminderEnabled &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TaskRowsCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String?> ownerUserId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> kind;
  final Value<String> location;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<String> timezoneId;
  final Value<String> repeatRuleJson;
  final Value<int> reminderMinutes;
  final Value<bool> reminderEnabled;
  final Value<String> status;
  final Value<int> priority;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TaskRowsCompanion({
    this.id = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.location = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.repeatRuleJson = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRowsCompanion.insert({
    required String id,
    this.ownerUserId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.location = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    required String timezoneId,
    this.repeatRuleJson = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        startAt = Value(startAt),
        endAt = Value(endAt),
        timezoneId = Value(timezoneId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? ownerUserId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? kind,
    Expression<String>? location,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? timezoneId,
    Expression<String>? repeatRuleJson,
    Expression<int>? reminderMinutes,
    Expression<bool>? reminderEnabled,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (kind != null) 'kind': kind,
      if (location != null) 'location': location,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (repeatRuleJson != null) 'repeat_rule_json': repeatRuleJson,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRowsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? ownerUserId,
      Value<String>? title,
      Value<String>? description,
      Value<String>? kind,
      Value<String>? location,
      Value<DateTime>? startAt,
      Value<DateTime>? endAt,
      Value<String>? timezoneId,
      Value<String>? repeatRuleJson,
      Value<int>? reminderMinutes,
      Value<bool>? reminderEnabled,
      Value<String>? status,
      Value<int>? priority,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return TaskRowsCompanion(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      location: location ?? this.location,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timezoneId: timezoneId ?? this.timezoneId,
      repeatRuleJson: repeatRuleJson ?? this.repeatRuleJson,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (repeatRuleJson.present) {
      map['repeat_rule_json'] = Variable<String>(repeatRuleJson.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRowsCompanion(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('location: $location, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('repeatRuleJson: $repeatRuleJson, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteRowsTable extends NoteRows with TableInfo<$NoteRowsTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerUserIdMeta =
      const VerificationMeta('ownerUserId');
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
      'owner_user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _bodyMarkdownMeta =
      const VerificationMeta('bodyMarkdown');
  @override
  late final GeneratedColumn<String> bodyMarkdown = GeneratedColumn<String>(
      'body_markdown', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsJsonMeta =
      const VerificationMeta('tagsJson');
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
      'tags_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ownerUserId,
        title,
        bodyMarkdown,
        tagsJson,
        isFavorite,
        version,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_rows';
  @override
  VerificationContext validateIntegrity(Insertable<NoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
          _ownerUserIdMeta,
          ownerUserId.isAcceptableOrUnknown(
              data['owner_user_id']!, _ownerUserIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body_markdown')) {
      context.handle(
          _bodyMarkdownMeta,
          bodyMarkdown.isAcceptableOrUnknown(
              data['body_markdown']!, _bodyMarkdownMeta));
    } else if (isInserting) {
      context.missing(_bodyMarkdownMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(_tagsJsonMeta,
          tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ownerUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_user_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      bodyMarkdown: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body_markdown'])!,
      tagsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_json'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $NoteRowsTable createAlias(String alias) {
    return $NoteRowsTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String? ownerUserId;
  final String title;
  final String bodyMarkdown;
  final String tagsJson;
  final bool isFavorite;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const NoteRow(
      {required this.id,
      this.ownerUserId,
      required this.title,
      required this.bodyMarkdown,
      required this.tagsJson,
      required this.isFavorite,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['title'] = Variable<String>(title);
    map['body_markdown'] = Variable<String>(bodyMarkdown);
    map['tags_json'] = Variable<String>(tagsJson);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  NoteRowsCompanion toCompanion(bool nullToAbsent) {
    return NoteRowsCompanion(
      id: Value(id),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      title: Value(title),
      bodyMarkdown: Value(bodyMarkdown),
      tagsJson: Value(tagsJson),
      isFavorite: Value(isFavorite),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory NoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      title: serializer.fromJson<String>(json['title']),
      bodyMarkdown: serializer.fromJson<String>(json['bodyMarkdown']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'title': serializer.toJson<String>(title),
      'bodyMarkdown': serializer.toJson<String>(bodyMarkdown),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  NoteRow copyWith(
          {String? id,
          Value<String?> ownerUserId = const Value.absent(),
          String? title,
          String? bodyMarkdown,
          String? tagsJson,
          bool? isFavorite,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      NoteRow(
        id: id ?? this.id,
        ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
        title: title ?? this.title,
        bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
        tagsJson: tagsJson ?? this.tagsJson,
        isFavorite: isFavorite ?? this.isFavorite,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  NoteRow copyWithCompanion(NoteRowsCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      ownerUserId:
          data.ownerUserId.present ? data.ownerUserId.value : this.ownerUserId,
      title: data.title.present ? data.title.value : this.title,
      bodyMarkdown: data.bodyMarkdown.present
          ? data.bodyMarkdown.value
          : this.bodyMarkdown,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('title: $title, ')
          ..write('bodyMarkdown: $bodyMarkdown, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ownerUserId, title, bodyMarkdown,
      tagsJson, isFavorite, version, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.ownerUserId == this.ownerUserId &&
          other.title == this.title &&
          other.bodyMarkdown == this.bodyMarkdown &&
          other.tagsJson == this.tagsJson &&
          other.isFavorite == this.isFavorite &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class NoteRowsCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String?> ownerUserId;
  final Value<String> title;
  final Value<String> bodyMarkdown;
  final Value<String> tagsJson;
  final Value<bool> isFavorite;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const NoteRowsCompanion({
    this.id = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.title = const Value.absent(),
    this.bodyMarkdown = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteRowsCompanion.insert({
    required String id,
    this.ownerUserId = const Value.absent(),
    required String title,
    required String bodyMarkdown,
    this.tagsJson = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        bodyMarkdown = Value(bodyMarkdown),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? ownerUserId,
    Expression<String>? title,
    Expression<String>? bodyMarkdown,
    Expression<String>? tagsJson,
    Expression<bool>? isFavorite,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (title != null) 'title': title,
      if (bodyMarkdown != null) 'body_markdown': bodyMarkdown,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteRowsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? ownerUserId,
      Value<String>? title,
      Value<String>? bodyMarkdown,
      Value<String>? tagsJson,
      Value<bool>? isFavorite,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return NoteRowsCompanion(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      title: title ?? this.title,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      tagsJson: tagsJson ?? this.tagsJson,
      isFavorite: isFavorite ?? this.isFavorite,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (bodyMarkdown.present) {
      map['body_markdown'] = Variable<String>(bodyMarkdown.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRowsCompanion(')
          ..write('id: $id, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('title: $title, ')
          ..write('bodyMarkdown: $bodyMarkdown, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TaskRowsTable taskRows = $TaskRowsTable(this);
  late final $NoteRowsTable noteRows = $NoteRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [taskRows, noteRows];
}

typedef $$TaskRowsTableCreateCompanionBuilder = TaskRowsCompanion Function({
  required String id,
  Value<String?> ownerUserId,
  required String title,
  Value<String> description,
  Value<String> kind,
  Value<String> location,
  required DateTime startAt,
  required DateTime endAt,
  required String timezoneId,
  Value<String> repeatRuleJson,
  Value<int> reminderMinutes,
  Value<bool> reminderEnabled,
  Value<String> status,
  Value<int> priority,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$TaskRowsTableUpdateCompanionBuilder = TaskRowsCompanion Function({
  Value<String> id,
  Value<String?> ownerUserId,
  Value<String> title,
  Value<String> description,
  Value<String> kind,
  Value<String> location,
  Value<DateTime> startAt,
  Value<DateTime> endAt,
  Value<String> timezoneId,
  Value<String> repeatRuleJson,
  Value<int> reminderMinutes,
  Value<bool> reminderEnabled,
  Value<String> status,
  Value<int> priority,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$TaskRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timezoneId => $composableBuilder(
      column: $table.timezoneId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get repeatRuleJson => $composableBuilder(
      column: $table.repeatRuleJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
      column: $table.reminderMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$TaskRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timezoneId => $composableBuilder(
      column: $table.timezoneId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get repeatRuleJson => $composableBuilder(
      column: $table.repeatRuleJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
      column: $table.reminderMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$TaskRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get timezoneId => $composableBuilder(
      column: $table.timezoneId, builder: (column) => column);

  GeneratedColumn<String> get repeatRuleJson => $composableBuilder(
      column: $table.repeatRuleJson, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
      column: $table.reminderMinutes, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TaskRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskRowsTable,
    TaskRow,
    $$TaskRowsTableFilterComposer,
    $$TaskRowsTableOrderingComposer,
    $$TaskRowsTableAnnotationComposer,
    $$TaskRowsTableCreateCompanionBuilder,
    $$TaskRowsTableUpdateCompanionBuilder,
    (TaskRow, BaseReferences<_$AppDatabase, $TaskRowsTable, TaskRow>),
    TaskRow,
    PrefetchHooks Function()> {
  $$TaskRowsTableTableManager(_$AppDatabase db, $TaskRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> ownerUserId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> location = const Value.absent(),
            Value<DateTime> startAt = const Value.absent(),
            Value<DateTime> endAt = const Value.absent(),
            Value<String> timezoneId = const Value.absent(),
            Value<String> repeatRuleJson = const Value.absent(),
            Value<int> reminderMinutes = const Value.absent(),
            Value<bool> reminderEnabled = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskRowsCompanion(
            id: id,
            ownerUserId: ownerUserId,
            title: title,
            description: description,
            kind: kind,
            location: location,
            startAt: startAt,
            endAt: endAt,
            timezoneId: timezoneId,
            repeatRuleJson: repeatRuleJson,
            reminderMinutes: reminderMinutes,
            reminderEnabled: reminderEnabled,
            status: status,
            priority: priority,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> ownerUserId = const Value.absent(),
            required String title,
            Value<String> description = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> location = const Value.absent(),
            required DateTime startAt,
            required DateTime endAt,
            required String timezoneId,
            Value<String> repeatRuleJson = const Value.absent(),
            Value<int> reminderMinutes = const Value.absent(),
            Value<bool> reminderEnabled = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskRowsCompanion.insert(
            id: id,
            ownerUserId: ownerUserId,
            title: title,
            description: description,
            kind: kind,
            location: location,
            startAt: startAt,
            endAt: endAt,
            timezoneId: timezoneId,
            repeatRuleJson: repeatRuleJson,
            reminderMinutes: reminderMinutes,
            reminderEnabled: reminderEnabled,
            status: status,
            priority: priority,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaskRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaskRowsTable,
    TaskRow,
    $$TaskRowsTableFilterComposer,
    $$TaskRowsTableOrderingComposer,
    $$TaskRowsTableAnnotationComposer,
    $$TaskRowsTableCreateCompanionBuilder,
    $$TaskRowsTableUpdateCompanionBuilder,
    (TaskRow, BaseReferences<_$AppDatabase, $TaskRowsTable, TaskRow>),
    TaskRow,
    PrefetchHooks Function()>;
typedef $$NoteRowsTableCreateCompanionBuilder = NoteRowsCompanion Function({
  required String id,
  Value<String?> ownerUserId,
  required String title,
  required String bodyMarkdown,
  Value<String> tagsJson,
  Value<bool> isFavorite,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$NoteRowsTableUpdateCompanionBuilder = NoteRowsCompanion Function({
  Value<String> id,
  Value<String?> ownerUserId,
  Value<String> title,
  Value<String> bodyMarkdown,
  Value<String> tagsJson,
  Value<bool> isFavorite,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$NoteRowsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteRowsTable> {
  $$NoteRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodyMarkdown => $composableBuilder(
      column: $table.bodyMarkdown, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$NoteRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteRowsTable> {
  $$NoteRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodyMarkdown => $composableBuilder(
      column: $table.bodyMarkdown,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$NoteRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteRowsTable> {
  $$NoteRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
      column: $table.ownerUserId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get bodyMarkdown => $composableBuilder(
      column: $table.bodyMarkdown, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$NoteRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteRowsTable,
    NoteRow,
    $$NoteRowsTableFilterComposer,
    $$NoteRowsTableOrderingComposer,
    $$NoteRowsTableAnnotationComposer,
    $$NoteRowsTableCreateCompanionBuilder,
    $$NoteRowsTableUpdateCompanionBuilder,
    (NoteRow, BaseReferences<_$AppDatabase, $NoteRowsTable, NoteRow>),
    NoteRow,
    PrefetchHooks Function()> {
  $$NoteRowsTableTableManager(_$AppDatabase db, $NoteRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> ownerUserId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> bodyMarkdown = const Value.absent(),
            Value<String> tagsJson = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteRowsCompanion(
            id: id,
            ownerUserId: ownerUserId,
            title: title,
            bodyMarkdown: bodyMarkdown,
            tagsJson: tagsJson,
            isFavorite: isFavorite,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> ownerUserId = const Value.absent(),
            required String title,
            required String bodyMarkdown,
            Value<String> tagsJson = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteRowsCompanion.insert(
            id: id,
            ownerUserId: ownerUserId,
            title: title,
            bodyMarkdown: bodyMarkdown,
            tagsJson: tagsJson,
            isFavorite: isFavorite,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NoteRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteRowsTable,
    NoteRow,
    $$NoteRowsTableFilterComposer,
    $$NoteRowsTableOrderingComposer,
    $$NoteRowsTableAnnotationComposer,
    $$NoteRowsTableCreateCompanionBuilder,
    $$NoteRowsTableUpdateCompanionBuilder,
    (NoteRow, BaseReferences<_$AppDatabase, $NoteRowsTable, NoteRow>),
    NoteRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TaskRowsTableTableManager get taskRows =>
      $$TaskRowsTableTableManager(_db, _db.taskRows);
  $$NoteRowsTableTableManager get noteRows =>
      $$NoteRowsTableTableManager(_db, _db.noteRows);
}
