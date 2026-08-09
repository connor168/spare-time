import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/knowledge_note.dart';

void main() {
  test('normalizes whitespace for search previews', () {
    final now = DateTime.utc(2026, 8, 7);
    final note = KnowledgeNote(
        id: 'note-1',
        title: 'Title',
        bodyMarkdown: 'First\n\nsecond',
        createdAt: now,
        updatedAt: now);
    expect(note.preview, 'First second');
  });

  test('preserves identity and increments an edited version', () {
    final now = DateTime.utc(2026, 8, 7);
    final note = KnowledgeNote(
        id: 'note-1',
        title: 'Title',
        bodyMarkdown: 'Body',
        createdAt: now,
        updatedAt: now);
    final edited = note.copyWith(title: 'Edited', version: note.version + 1);
    expect(edited.id, note.id);
    expect(edited.version, 2);
  });
}
