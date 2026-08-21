import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/planner_task.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key, this.original});

  final PlannerTask? original;

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  static const _disabledReminderValue = -1;

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController locationController;
  late DateTime date;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late ScheduleItemKind kind;
  late bool reminderEnabled;
  late int reminderMinutes;
  late int priority;
  String? errorText;

  bool get isEditing => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    titleController = TextEditingController(text: original?.title ?? '');
    descriptionController =
        TextEditingController(text: original?.description ?? '');
    locationController = TextEditingController(text: original?.location ?? '');
    kind = original?.kind ?? ScheduleItemKind.task;
    reminderEnabled = original?.reminderEnabled ?? true;
    reminderMinutes = original?.reminderMinutes ?? 5;
    priority = original?.priority ?? 2;

    if (original != null) {
      final localStart = original.startAt.toLocal();
      final localEnd = original.endAt.toLocal();
      date = DateTime(localStart.year, localStart.month, localStart.day);
      startTime = TimeOfDay.fromDateTime(localStart);
      endTime = TimeOfDay.fromDateTime(localEnd);
      return;
    }

    final now = DateTime.now();
    final safeStart =
        now.hour >= 23 ? DateTime(now.year, now.month, now.day, 22, 30) : now;
    date = DateTime(safeStart.year, safeStart.month, safeStart.day);
    startTime = TimeOfDay.fromDateTime(safeStart);
    endTime = TimeOfDay.fromDateTime(
      safeStart.add(const Duration(minutes: 30)),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '编辑安排' : '添加安排'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ScheduleItemKind>(
                key: const Key('task-kind-field'),
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: '类型',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ScheduleItemKind.course,
                    child: Text('课程'),
                  ),
                  DropdownMenuItem(
                    value: ScheduleItemKind.task,
                    child: Text('学习任务'),
                  ),
                  DropdownMenuItem(
                    value: ScheduleItemKind.timeBlock,
                    child: Text('时间段'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => kind = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('task-title-field'),
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _titleLabel,
                  hintText: _titleHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('task-description-field'),
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '说明',
                  hintText: '补充目标、链接或上下文',
                ),
              ),
              if (kind == ScheduleItemKind.course) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('task-location-field'),
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: '上课地点',
                    hintText: '例如：教学楼 A201',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PickerRow(
                icon: Icons.calendar_today_outlined,
                label: '日期',
                value:
                    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}',
                onTap: _pickDate,
              ),
              _PickerRow(
                icon: Icons.schedule_outlined,
                label: '开始',
                value: startTime.format(context),
                onTap: () => _pickTime(isStart: true),
              ),
              _PickerRow(
                icon: Icons.schedule,
                label: '结束',
                value: endTime.format(context),
                onTap: () => _pickTime(isStart: false),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: const Key('task-reminder-field'),
                initialValue:
                    reminderEnabled ? reminderMinutes : _disabledReminderValue,
                decoration: const InputDecoration(
                  labelText: '提醒',
                  prefixIcon: Icon(Icons.notifications_none),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _disabledReminderValue,
                    child: Text('关闭提醒'),
                  ),
                  DropdownMenuItem(value: 0, child: Text('准时提醒')),
                  DropdownMenuItem(value: 5, child: Text('提前 5 分钟')),
                  DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
                  DropdownMenuItem(value: 30, child: Text('提前 30 分钟')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    reminderEnabled = value != _disabledReminderValue;
                    if (reminderEnabled) reminderMinutes = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('低')),
                  ButtonSegment(value: 2, label: Text('中')),
                  ButtonSegment(value: 3, label: Text('高')),
                ],
                selected: {priority},
                onSelectionChanged: (selection) =>
                    setState(() => priority = selection.single),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }

  String get _titleLabel => switch (kind) {
        ScheduleItemKind.course => '课程名称',
        ScheduleItemKind.task => '任务名称',
        ScheduleItemKind.timeBlock => '时间段名称',
      };

  String get _titleHint => switch (kind) {
        ScheduleItemKind.course => '例如：高等数学',
        ScheduleItemKind.task => '例如：完成产品规格',
        ScheduleItemKind.timeBlock => '例如：午休',
      };

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate:
          isEditing ? DateTime(2000) : now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        startTime = selected;
      } else {
        endTime = selected;
      }
    });
  }

  void _save() {
    final title = titleController.text.trim();
    final start = _combine(date, startTime);
    final end = _combine(date, endTime);
    if (title.isEmpty) {
      setState(() => errorText = '请输入$_titleLabel。');
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => errorText = '结束时间必须晚于开始时间。跨天安排将在后续版本支持。');
      return;
    }

    final location =
        kind == ScheduleItemKind.course ? locationController.text.trim() : '';
    final original = widget.original;
    final result = original == null
        ? PlannerTask(
            id: const Uuid().v4(),
            title: title,
            description: descriptionController.text.trim(),
            startAt: start.toUtc(),
            endAt: end.toUtc(),
            timeZoneId: 'Asia/Shanghai',
            reminderMinutes: reminderMinutes,
            reminderEnabled: reminderEnabled,
            priority: priority,
            kind: kind,
            location: location,
            status: TaskStatus.planned,
          )
        : original.copyWith(
            title: title,
            description: descriptionController.text.trim(),
            startAt: start.toUtc(),
            endAt: end.toUtc(),
            reminderMinutes: reminderMinutes,
            reminderEnabled: reminderEnabled,
            priority: priority,
            kind: kind,
            location: location,
          );

    Navigator.pop(context, result);
  }

  DateTime _combine(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: TextButton(onPressed: onTap, child: Text(value)),
      onTap: onTap,
    );
  }
}
