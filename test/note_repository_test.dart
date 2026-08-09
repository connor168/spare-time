import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flow/data/app_database.dart';
import 'package:focus_flow/data/knowledge_note_repository.dart';
import 'package:focus_flow/domain/knowledge_note.dart';

void main() {
  late AppDatabase database;
  late DriftNoteRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftNoteRepository(database);
  });

  tearDown(() => database.close());

  KnowledgeNote buildNote({String id = 'note-1', int version = 1}) {
    final created = DateTime.utc(2026, 8, 8, 9);
    return KnowledgeNote(
      id: id,
      title: 'Focus patterns',
      bodyMarkdown: 'Use a small experiment before committing to a large plan.',
      createdAt: created,
      updatedAt: created,
      version: version,
    );
  }

  test('saves and loads a note with UTC timestamps', () async {
    final note = buildNote();
    await repository.saveNote(note);

    final loaded = await repository.loadNotes();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, note.id);
    expect(loaded.single.title, note.title);
    expect(loaded.single.bodyMarkdown, note.bodyMarkdown);
    expect(loaded.single.createdAt, note.createdAt);
    expect(loaded.single.createdAt.isUtc, isTrue);
    expect(loaded.single.version, note.version);
  });

  test(
      'preserves createdAt, increments version, and retains tags/favorite on update',
      () async {
    final note = buildNote();
    await repository
        .saveNote(note.copyWith(tags: const ['dart'], isFavorite: true));

    final updated = note.copyWith(
        title: 'Updated focus patterns',
        updatedAt: DateTime.utc(2026, 8, 8, 10),
        tags: const ['dart'],
        isFavorite: true);
    await repository.saveNote(updated);

    final row = await (database.select(database.noteRows)
          ..where((candidate) => candidate.id.equals(note.id)))
        .getSingle();
    expect(row.createdAt.toUtc(), note.createdAt);
    expect(row.version, 2);
    expect(row.tagsJson, '["dart"]');
    expect(row.isFavorite, isTrue);
    expect((await repository.loadNotes()).single.title, updated.title);
  });

  test('searches title and body while excluding soft deleted notes', () async {
    await repository.saveNote(buildNote());
    await repository.saveNote(buildNote(id: 'note-2').copyWith(
        title: 'Calendar', bodyMarkdown: 'Remember the review window.'));
    await repository.deleteNote('note-1');

    expect((await repository.searchNotes('focus')), isEmpty);
    expect((await repository.searchNotes('review')).single.id, 'note-2');
    expect(await repository.searchNotes(''), hasLength(1));
  });

  test('saving a deleted note revives it without losing its identity',
      () async {
    final note = buildNote();
    await repository.saveNote(note);
    await repository.deleteNote(note.id);
    await repository.saveNote(note.copyWith(title: 'Restored'));

    final loaded = await repository.loadNotes();
    expect(loaded.single.title, 'Restored');
    expect(loaded.single.deletedAt, isNull);
  });
}
