import '../domain/planner_task.dart';

abstract interface class NotificationScheduler {
  Future<void> initialize();

  /// Requests notification permission at a user-initiated point in the UI.
  ///
  /// [initialize] deliberately does not show a system permission prompt.
  Future<bool> requestPermissions();

  Future<void> schedule(PlannerTask task);

  Future<void> cancel(String taskId);

  Future<void> cancelAll();

  Future<void> rescheduleAll(Iterable<PlannerTask> tasks);
}

class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(PlannerTask task) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> rescheduleAll(Iterable<PlannerTask> tasks) async {}
}
