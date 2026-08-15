import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/planner_task.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  DateTime date = DateTime.now();
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  int reminderMinutes = 5;
  int priority = 2;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final safeStart =
        now.hour >= 23 ? DateTime(now.year, now.month, now.day, 22, 30) : now;
    startTime = TimeOfDay.fromDateTime(safeStart);
    final end = safeStart.add(const Duration(minutes: 30));
    endTime = TimeOfDay.fromDateTime(end);
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加任务'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                key: const Key('task-title-field'),
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '任务名称', hintText: '例如：完成产品规格')),
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
            const SizedBox(height: 14),
            _PickerRow(
                icon: Icons.calendar_today_outlined,
                label: '日期',
                value:
                    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}',
                onTap: _pickDate),
            _PickerRow(
                icon: Icons.schedule_outlined,
                label: '开始',
                value: startTime.format(context),
                onTap: () => _pickTime(isStart: true)),
            _PickerRow(
                icon: Icons.schedule,
                label: '结束',
                value: endTime.format(context),
                onTap: () => _pickTime(isStart: false)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: reminderMinutes,
              decoration: const InputDecoration(
                  labelText: '提前提醒',
                  prefixIcon: Icon(Icons.notifications_none)),
              items: const [
                DropdownMenuItem(value: 0, child: Text('准时提醒')),
                DropdownMenuItem(value: 5, child: Text('提前 5 分钟')),
                DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
                DropdownMenuItem(value: 30, child: Text('提前 30 分钟')),
              ],
              onChanged: (value) =>
                  setState(() => reminderMinutes = value ?? 5),
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
                    child: Text(errorText!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('添加')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
        context: context, initialTime: isStart ? startTime : endTime);
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
      setState(() => errorText = '请输入任务名称。');
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => errorText = '结束时间必须晚于开始时间。跨天任务将在后续版本支持。');
      return;
    }

    Navigator.pop(
      context,
      PlannerTask(
        id: const Uuid().v4(),
        title: title,
        description: descriptionController.text.trim(),
        startAt: start.toUtc(),
        endAt: end.toUtc(),
        timeZoneId: 'Asia/Shanghai',
        reminderMinutes: reminderMinutes,
        priority: priority,
      ),
    );
  }

  DateTime _combine(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _PickerRow extends StatelessWidget {
  const _PickerRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

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
