import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CourseReminderPreferenceStore {
  Future<bool> load();

  Future<void> save(bool enabled);
}

class SecureCourseReminderPreferenceStore
    implements CourseReminderPreferenceStore {
  SecureCourseReminderPreferenceStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'course_reminders_enabled';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> load() async {
    final value = await _storage.read(key: _key);
    return value != 'false';
  }

  @override
  Future<void> save(bool enabled) =>
      _storage.write(key: _key, value: enabled.toString());
}

class InMemoryCourseReminderPreferenceStore
    implements CourseReminderPreferenceStore {
  InMemoryCourseReminderPreferenceStore({bool enabled = true})
      : _enabled = enabled;

  bool _enabled;

  @override
  Future<bool> load() async => _enabled;

  @override
  Future<void> save(bool enabled) async => _enabled = enabled;
}
