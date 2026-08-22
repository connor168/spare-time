import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/planner_task.dart';

class DailyPlanner {
  const DailyPlanner({this.sessionMinutes = 50, this.breakMinutes = 10})
      : assert(sessionMinutes > 0),
        assert(breakMinutes >= 0);

  final int sessionMinutes;
  final int breakMinutes;

  List<PlannerTask> generate({
    required DateTime day,
    required Iterable<PlannerTask> existing,
    int workStartMinute = 9 * 60,
    int workEndMinute = 21 * 60,
    int targetMinutes = 120,
  }) {
    if (workStartMinute < 0 || workEndMinute > 24 * 60 || workEndMinute <= workStartMinute) {
      throw ArgumentError('工作时间范围无效');
    }
    if (targetMinutes <= 0) return const [];
    tz_data.initializeTimeZones();
    final location = tz.getLocation('Asia/Shanghai');
    final localDay = tz.TZDateTime(location, day.year, day.month, day.day);
    final items = existing
        .where((task) => task.recurrence != TaskRecurrence.weekly)
        .where((task) => _sameDay(tz.TZDateTime.from(task.startAt.toUtc(), location), localDay))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final recurring = existing.where((task) =>
        task.recurrence == TaskRecurrence.weekly &&
        tz.TZDateTime.from(task.startAt.toUtc(), location).weekday == localDay.weekday).map((task) {
      final localStart = tz.TZDateTime.from(task.startAt.toUtc(), location);
      final start = tz.TZDateTime(location, localDay.year, localDay.month, localDay.day,
          localStart.hour, localStart.minute).toUtc();
      final end = start.add(task.endAt.difference(task.startAt));
      return task.copyWith(startAt: start, endAt: end);
    });
    items.addAll(recurring);
    items.sort((a, b) => a.startAt.compareTo(b.startAt));

    final result = <PlannerTask>[];
    DateTime cursor = tz.TZDateTime(location, localDay.year, localDay.month, localDay.day,
            0, workStartMinute)
        .toUtc();
    var remaining = targetMinutes;
    for (final item in items) {
      final gap = item.startAt.difference(cursor).inMinutes;
      if (gap >= sessionMinutes && remaining >= sessionMinutes) {
        final availableSessions =
            ((gap - sessionMinutes) ~/ (sessionMinutes + breakMinutes)) + 1;
        final count = availableSessions < remaining ~/ sessionMinutes
            ? availableSessions
            : remaining ~/ sessionMinutes;
        for (var i = 0; i < count && remaining >= sessionMinutes; i++) {
          final start = cursor.add(Duration(minutes: i * (sessionMinutes + breakMinutes)));
          final end = start.add(Duration(minutes: sessionMinutes));
          result.add(_block(start, end));
          remaining -= sessionMinutes;
        }
      }
      if (item.endAt.isAfter(cursor)) cursor = item.endAt;
    }
    final DateTime endOfDay = tz.TZDateTime(location, localDay.year, localDay.month, localDay.day,
            0, workEndMinute)
        .toUtc();
    while (remaining >= sessionMinutes &&
        endOfDay.difference(cursor).inMinutes >= sessionMinutes) {
      final end = cursor.add(Duration(minutes: sessionMinutes));
      result.add(_block(cursor, end));
      cursor = end.add(Duration(minutes: breakMinutes));
      remaining -= sessionMinutes;
    }
    return result;
  }

  PlannerTask _block(DateTime start, DateTime end) => PlannerTask(
        id: const Uuid().v4(),
        title: '专注学习',
        kind: ScheduleItemKind.timeBlock,
        startAt: start,
        endAt: end,
        timeZoneId: 'Asia/Shanghai',
        reminderMinutes: 5,
      );

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
