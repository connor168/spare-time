import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/planner_task.dart';

class ScheduleHistoryView extends StatelessWidget {
  const ScheduleHistoryView({super.key, required this.tasks});

  final List<PlannerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final history = tasks
        .where((task) => task.status != TaskStatus.planned)
        .toList()
      ..sort((left, right) => right.startAt.compareTo(left.startAt));

    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 52, color: Colors.black38),
              SizedBox(height: 12),
              Text('还没有完成记录'),
              SizedBox(height: 6),
              Text('完成或标记为今日未完成的项目会保留在这里。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('schedule-history-list'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      itemCount: history.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 18) : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('历史记录',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('已完成和今日未完成都会保留，不会自动顺延到第二天。',
                  style: TextStyle(color: Colors.black54)),
            ],
          );
        }
        return _HistoryTile(task: history[index - 1]);
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.task});

  final PlannerTask task;

  @override
  Widget build(BuildContext context) {
    final incomplete = task.status == TaskStatus.todayIncomplete;
    final color =
        incomplete ? const Color(0xffa85f00) : const Color(0xff157a6e);
    final icon = incomplete ? Icons.pending_actions : Icons.task_alt;
    final status = incomplete ? '今日未完成' : '已完成';
    final local = _localStart(task);
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(task.title),
        subtitle: Text('$date  $time${_details(task)}'),
        trailing: Text(status,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  DateTime _localStart(PlannerTask task) {
    try {
      return tz.TZDateTime.from(
          task.startAt.toUtc(), tz.getLocation(task.timeZoneId));
    } on Exception {
      return task.startAt.toLocal();
    }
  }

  String _details(PlannerTask task) {
    if (task.location.trim().isEmpty) return '';
    return ' · ${task.location.trim()}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
