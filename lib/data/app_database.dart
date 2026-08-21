import 'package:drift/drift.dart';

part 'app_database.g.dart';

class TaskRows extends Table {
  TextColumn get id => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get kind => text().withDefault(const Constant('task'))();
  TextColumn get location => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  TextColumn get timezoneId => text()();
  TextColumn get repeatRuleJson =>
      text().withDefault(const Constant('{"type":"none"}'))();
  IntColumn get reminderMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  IntColumn get priority => integer().withDefault(const Constant(2))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NoteRows extends Table {
  TextColumn get id => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get bodyMarkdown => text()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [TaskRows, NoteRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(taskRows, taskRows.ownerUserId);
            await m.addColumn(noteRows, noteRows.ownerUserId);
          }
          if (from < 3) {
            await m.addColumn(taskRows, taskRows.kind);
            await m.addColumn(taskRows, taskRows.location);
            await m.addColumn(taskRows, taskRows.reminderEnabled);
          }
        },
      );
}
