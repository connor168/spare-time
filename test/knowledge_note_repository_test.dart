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

  test('persists note metadata and increments version on update', () async {
    final created = DateTime.utc(2026, 8, 8, 1);
    await repository.saveNote(KnowledgeNote(
        id: 'n1',
        title: 'First',
        bodyMarkdown: 'Body',
        tags: const ['ai'],
        isFavorite: true,
        createdAt: created,
        updatedAt: created));
    await repository.saveNote(KnowledgeNote(
        id: 'n1',
        title: 'Edited',
        bodyMarkdown: 'Updated',
        tags: const ['ai', 'work'],
        createdAt: created,
        updatedAt: created));

    final loaded = await repository.loadNotes();
    expect(loaded.single.title, 'Edited');
    expect(loaded.single.tags, ['ai', 'work']);
    expect(loaded.single.version, 2);
    expect(loaded.single.createdAt, created);
  });

  test('searches title, body, and tags and soft deletes', () async {
    final now = DateTime.utc(2026, 8, 8);
    await repository.saveNote(KnowledgeNote(
        id: 'n1',
        title: 'Flutter',
        bodyMarkdown: 'SQLite',
        tags: const ['mobile'],
        createdAt: now,
        updatedAt: now));
    expect((await repository.searchNotes('mobile')).single.id, 'n1');
    await repository.deleteNote('n1');
    expect(await repository.loadNotes(), isEmpty);
    final tombstone = (await repository.loadNotes(includeDeleted: true)).single;
    expect(tombstone.deletedAt, isNotNull);
    expect(tombstone.version, 2);
  });

  test('owner scopes isolate local notes between accounts', () async {
    final note = KnowledgeNote(
      id: 'owner-note',
      title: 'Private note',
      bodyMarkdown: '',
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
    );
    repository.setOwner('user-a');
    await repository.saveNote(note);
    repository.setOwner('user-b');
    expect(await repository.loadNotes(), isEmpty);
    repository.setOwner('user-a');
    expect((await repository.loadNotes()).single.title, 'Private note');
  });
}
