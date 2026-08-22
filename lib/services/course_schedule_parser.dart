import 'dart:convert';

import '../domain/course_draft.dart';

class CourseScheduleParser {
  const CourseScheduleParser();

  List<CourseDraft> parseJson(String input) {
    dynamic decoded;
    try {
      decoded = jsonDecode(input);
    } on FormatException {
      return parseText(input);
    }
    final values = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['courses']
            : null;
    if (values is! List) throw const FormatException('课表 JSON 必须包含 courses 数组');
    final drafts = values
        .map((value) => CourseDraft.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList(growable: false);
    if (drafts.isEmpty) throw const FormatException('没有识别到课程');
    return drafts;
  }

  /// Accepts common OCR output lines such as: `周一 高等数学 08:00-09:40 A203`.
  /// This keeps image recognition separate from schedule validation: Android or
  /// a future server OCR service can pass its plain text result here.
  List<CourseDraft> parseText(String input) {
    final drafts = <CourseDraft>[];
    for (final raw in input.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^(?:周)?([一二三四五六日天1-7])\s+(.+?)\s+(\d{1,2}:\d{2})\s*[-~至]\s*(\d{1,2}:\d{2})(?:\s+(.+))?$',
      ).firstMatch(line);
      if (match == null) continue;
      final day = _weekday(match.group(1)!);
      drafts.add(CourseDraft.fromJson({
        'name': match.group(2),
        'weekday': day,
        'start': match.group(3),
        'end': match.group(4),
        'location': match.group(5) ?? '',
      }));
    }
    if (drafts.isEmpty) throw const FormatException('未识别到课程，请使用 JSON 或“周一 课程名 08:00-09:40 地点”格式');
    return drafts;
  }

  int _weekday(String value) => switch (value) {
        '一' || '1' => 1,
        '二' || '2' => 2,
        '三' || '3' => 3,
        '四' || '4' => 4,
        '五' || '5' => 5,
        '六' || '6' => 6,
        _ => 7,
      };
}
