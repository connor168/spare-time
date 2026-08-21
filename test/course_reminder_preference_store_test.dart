import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/services/course_reminder_preference_store.dart';

void main() {
  test('in-memory course reminder preference persists changes', () async {
    final store = InMemoryCourseReminderPreferenceStore();

    expect(await store.load(), isTrue);
    await store.save(false);
    expect(await store.load(), isFalse);
  });
}
