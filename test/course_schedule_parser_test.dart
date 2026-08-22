import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/services/course_schedule_parser.dart';

void main() {
  test('parses validated course JSON drafts', () {
    final drafts = const CourseScheduleParser().parseJson('''
      {"courses":[{"name":"高等数学","weekday":1,"start":"08:00","end":"09:40","location":"A203"}]}
    ''');
    expect(drafts.single.name, '高等数学');
    expect(drafts.single.startMinute, 480);
    expect(drafts.single.endMinute, 580);
  });

  test('rejects invalid course time', () {
    expect(() => const CourseScheduleParser().parseJson(
        '[{"name":"数学","weekday":1,"start":"10:00","end":"09:00"}]'), throwsFormatException);
  });

  test('parses plain OCR text lines', () {
    final drafts = const CourseScheduleParser().parseText('周三 操作系统 14:00-15:40 教学楼 B201');
    expect(drafts.single.weekday, 3);
    expect(drafts.single.location, '教学楼 B201');
  });
}
