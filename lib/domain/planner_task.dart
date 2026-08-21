enum TaskRecurrence { none, daily, weekly }

enum ScheduleItemKind { task, course, timeBlock }

enum TaskStatus { planned, completed, todayIncomplete }

extension ScheduleItemKindStorage on ScheduleItemKind {
  String get storageValue => switch (this) {
        ScheduleItemKind.task => 'task',
        ScheduleItemKind.course => 'course',
        ScheduleItemKind.timeBlock => 'time_block',
      };
}

ScheduleItemKind scheduleItemKindFromStorage(Object? value) => switch (value) {
      'course' => ScheduleItemKind.course,
      'time_block' || 'timeBlock' => ScheduleItemKind.timeBlock,
      _ => ScheduleItemKind.task,
    };

extension TaskStatusStorage on TaskStatus {
  String get storageValue => switch (this) {
        TaskStatus.planned => 'planned',
        TaskStatus.completed => 'completed',
        TaskStatus.todayIncomplete => 'today_incomplete',
      };
}

TaskStatus taskStatusFromStorage(Object? value) => switch (value) {
      'completed' => TaskStatus.completed,
      'today_incomplete' || 'todayIncomplete' => TaskStatus.todayIncomplete,
      _ => TaskStatus.planned,
    };

const _notProvided = Object();

class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.timeZoneId,
    this.description = '',
    this.kind = ScheduleItemKind.task,
    this.location = '',
    this.priority = 2,
    this.reminderMinutes = 5,
    this.reminderEnabled = true,
    this.recurrence = TaskRecurrence.none,
    TaskStatus status = TaskStatus.planned,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.deletedAt,
  }) : status = isCompleted == null
            ? status
            : isCompleted
                ? TaskStatus.completed
                : status == TaskStatus.completed
                    ? TaskStatus.planned
                    : status {
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
  final ScheduleItemKind kind;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String timeZoneId;
  final int reminderMinutes;
  final bool reminderEnabled;
  final int priority;
  final TaskRecurrence recurrence;
  final TaskStatus status;
  late final DateTime createdAt;
  late final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isCompleted => status == TaskStatus.completed;

  DateTime get notificationAt =>
      startAt.subtract(Duration(minutes: reminderMinutes));

  bool isOverdueAt(DateTime now) => !isCompleted && endAt.isBefore(now);

  PlannerTask copyWith({
    String? title,
    String? description,
    ScheduleItemKind? kind,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    String? timeZoneId,
    int? reminderMinutes,
    bool? reminderEnabled,
    int? priority,
    TaskRecurrence? recurrence,
    TaskStatus? status,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    Object? deletedAt = _notProvided,
  }) {
    final nextStatus = isCompleted == null
        ? status ?? this.status
        : isCompleted
            ? TaskStatus.completed
            : status ??
                (this.status == TaskStatus.completed
                    ? TaskStatus.planned
                    : this.status);
    return PlannerTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      location: location ?? this.location,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      status: nextStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deletedAt: identical(deletedAt, _notProvided)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}
