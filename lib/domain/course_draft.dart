class CourseDraft {
  const CourseDraft({
    required this.name,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.location = '',
    this.firstWeek,
    this.lastWeek,
  });

  final String name;
  final int weekday;
  final int startMinute;
  final int endMinute;
  final String location;
  final int? firstWeek;
  final int? lastWeek;

  factory CourseDraft.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['course_name'] ?? '').toString().trim();
    final weekday = _int(json['weekday'] ?? json['day']);
    final start = _parseMinute(json['start_minute'] ?? json['start']);
    final end = _parseMinute(json['end_minute'] ?? json['end']);
    if (name.isEmpty) throw const FormatException('课程名称不能为空');
    if (weekday < 1 || weekday > 7) throw const FormatException('星期必须是 1 到 7');
    if (start < 0 || end <= start || end > 24 * 60) {
      throw const FormatException('课程时间无效');
    }
    final firstWeek = _optionalInt(json['first_week']);
    final lastWeek = _optionalInt(json['last_week']);
    if (firstWeek != null && (firstWeek < 1 || firstWeek > 16) ||
        lastWeek != null && (lastWeek < 1 || lastWeek > 16) ||
        firstWeek != null && lastWeek != null && lastWeek < firstWeek) {
      throw const FormatException('课程周次必须在 1 到 16 周内，且结束周不能早于开始周');
    }
    return CourseDraft(
      name: name,
      weekday: weekday,
      startMinute: start,
      endMinute: end,
      location: (json['location'] ?? '').toString().trim(),
      firstWeek: firstWeek,
      lastWeek: lastWeek,
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static int? _optionalInt(Object? value) => value == null ? null : int.tryParse('$value');

  static int _parseMinute(Object? value) {
    if (value is num) return value.toInt();
    final text = '$value'.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match != null) return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    return int.tryParse(text) ?? -1;
  }
}
