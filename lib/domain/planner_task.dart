enum TaskRecurrence { none, daily, weekly }

const _notProvided = Object();

class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.timeZoneId,
    this.description = '',
    this.priority = 2,
    this.reminderMinutes = 0,
    this.recurrence = TaskRecurrence.none,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.deletedAt,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Task title cannot be empty.');
    }
    if (endAt.isBefore(startAt)) {
      throw ArgumentError.value(
          endAt, 'endAt', 'Task end cannot precede its start.');
    }
    if (!startAt.isUtc || !endAt.isUtc) {
      throw ArgumentError('Task instants must be stored in UTC.');
    }
    this.createdAt = (createdAt ?? DateTime.now().toUtc()).toUtc();
    this.updatedAt = (updatedAt ?? this.createdAt).toUtc();
    if (!this.createdAt.isUtc || !this.updatedAt.isUtc) {
      throw ArgumentError('Task metadata must be stored in UTC.');
    }
    if (reminderMinutes < 0) {
      throw ArgumentError.value(
          reminderMinutes, 'reminderMinutes', 'Reminder cannot be negative.');
    }
    if (priority < 1 || priority > 3) {
      throw ArgumentError.value(
          priority, 'priority', 'Priority must be between 1 and 3.');
    }
    if (timeZoneId != 'UTC' && !timeZoneId.contains('/')) {
      throw ArgumentError.value(timeZoneId, 'timeZoneId',
          'Use an IANA time zone ID such as Asia/Tokyo.');
    }
  }

  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String timeZoneId;
  final int reminderMinutes;
  final int priority;
  final TaskRecurrence recurrence;
  final bool isCompleted;
  late final DateTime createdAt;
  late final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  DateTime get notificationAt =>
      startAt.subtract(Duration(minutes: reminderMinutes));

  bool isOverdueAt(DateTime now) => !isCompleted && endAt.isBefore(now);

  PlannerTask copyWith({
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    String? timeZoneId,
    int? reminderMinutes,
    int? priority,
    TaskRecurrence? recurrence,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    Object? deletedAt = _notProvided,
  }) {
    return PlannerTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deletedAt: identical(deletedAt, _notProvided)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}
