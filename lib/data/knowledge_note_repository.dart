import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/knowledge_note.dart';
import 'app_database.dart';

abstract interface class NoteRepository {
  String? get ownerUserId;

  void setOwner(String? ownerUserId);

  Future<List<KnowledgeNote>> loadNotes({
    String? query,
    bool includeDeleted = false,
  });

  Future<List<KnowledgeNote>> searchNotes(String query);

  Future<void> saveNote(KnowledgeNote note);

  Future<void> applyRemoteNote(KnowledgeNote note);

  Future<void> deleteNote(String noteId);
}

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this.database, {String? ownerUserId})
      : _ownerUserId = ownerUserId;

  final AppDatabase database;
  String? _ownerUserId;

  @override
  String? get ownerUserId => _ownerUserId;

  @override
  void setOwner(String? ownerUserId) => _ownerUserId = ownerUserId;

  @override
  Future<List<KnowledgeNote>> loadNotes({
    String? query,
    bool includeDeleted = false,
  }) async {
    final select = database.select(database.noteRows)
      ..orderBy([
        (row) => OrderingTerm(
              expression: row.updatedAt,
              mode: OrderingMode.desc,
            )
      ]);
    if (_ownerUserId == null) {
      select.where((row) => row.ownerUserId.isNull());
    } else {
      select.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    if (!includeDeleted) select.where((row) => row.deletedAt.isNull());
    final rows = await select.get();
    final notes = rows.map(_toDomain).toList(growable: false);
    final normalized = query?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return notes;
    return notes
        .where((note) =>
            note.title.toLowerCase().contains(normalized) ||
            note.bodyMarkdown.toLowerCase().contains(normalized) ||
            note.tags.any((tag) => tag.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }

  @override
  Future<List<KnowledgeNote>> searchNotes(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return loadNotes();

    // Filtering in Dart keeps matching Unicode-aware and prevents user input
    // from being interpreted as a SQL LIKE pattern.
    final notes = await loadNotes();
    return notes
        .where((note) =>
            note.title.toLowerCase().contains(normalized) ||
            note.bodyMarkdown.toLowerCase().contains(normalized) ||
            note.tags.any((tag) => tag.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }

  @override
  Future<void> saveNote(KnowledgeNote note) async {
    final now = DateTime.now().toUtc();
    final existingQuery = database.select(database.noteRows)
      ..where((row) => row.id.equals(note.id));
    if (_ownerUserId == null) {
      existingQuery.where((row) => row.ownerUserId.isNull());
    } else {
      existingQuery.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    final existing = await existingQuery.getSingleOrNull();
    final version = existing == null
        ? note.version
        : (note.version > existing.version
            ? note.version
            : existing.version + 1);

    await database.into(database.noteRows).insertOnConflictUpdate(
          NoteRowsCompanion.insert(
            id: note.id,
            ownerUserId: Value(_ownerUserId),
            title: note.title.trim(),
            bodyMarkdown: note.bodyMarkdown,
            tagsJson: Value(jsonEncode(note.tags)),
            isFavorite: Value(note.isFavorite),
            version: Value(version),
            createdAt: (existing?.createdAt ?? note.createdAt).toUtc(),
            updatedAt: note.updatedAt.toUtc().isAfter(now)
                ? note.updatedAt.toUtc()
                : now,
            // Saving a note revives a previously soft-deleted row.
            deletedAt: const Value(null),
          ),
        );
  }

  @override
  Future<void> applyRemoteNote(KnowledgeNote note) {
    return database.into(database.noteRows).insertOnConflictUpdate(
          NoteRowsCompanion.insert(
            id: note.id,
            ownerUserId: Value(_ownerUserId),
            title: note.title.trim(),
            bodyMarkdown: note.bodyMarkdown,
            tagsJson: Value(jsonEncode(note.tags)),
            isFavorite: Value(note.isFavorite),
            version: Value(note.version),
            createdAt: note.createdAt.toUtc(),
            updatedAt: note.updatedAt.toUtc(),
            deletedAt: Value(note.deletedAt?.toUtc()),
          ),
        );
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final existingQuery = database.select(database.noteRows)
      ..where((row) => row.id.equals(noteId));
    if (_ownerUserId == null) {
      existingQuery.where((row) => row.ownerUserId.isNull());
    } else {
      existingQuery.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    final existing = await existingQuery.getSingleOrNull();
    if (existing == null || existing.deletedAt != null) return;

    final now = DateTime.now().toUtc();
    final update = database.update(database.noteRows)
      ..where((row) => row.id.equals(noteId));
    if (_ownerUserId == null) {
      update.where((row) => row.ownerUserId.isNull());
    } else {
      update.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    await update.write(
      NoteRowsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        version: Value(existing.version + 1),
      ),
    );
  }

  KnowledgeNote _toDomain(NoteRow row) {
    return KnowledgeNote(
      id: row.id,
      title: row.title,
      bodyMarkdown: row.bodyMarkdown,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      version: row.version,
      tags: _decodeTags(row.tagsJson),
      isFavorite: row.isFavorite,
      deletedAt: row.deletedAt?.toUtc(),
    );
  }

  List<String> _decodeTags(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on Object {
      // Keep malformed legacy rows readable.
    }
    return const [];
  }
}

class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository(
      {Iterable<KnowledgeNote> seed = const [], String? ownerUserId})
      : _notes = [...seed],
        _ownerUserId = ownerUserId {
    for (final note in _notes) {
      _owners[note.id] = ownerUserId;
    }
  }

  final List<KnowledgeNote> _notes;
  final Map<String, String?> _owners = {};
  String? _ownerUserId;

  @override
  String? get ownerUserId => _ownerUserId;

  @override
  void setOwner(String? ownerUserId) => _ownerUserId = ownerUserId;

  @override
  Future<List<KnowledgeNote>> loadNotes({
    String? query,
    bool includeDeleted = false,
  }) async {
    final notes = (includeDeleted ? _notes : _activeNotes)
        .where((note) => _owners[note.id] == _ownerUserId)
        .toList();
    final normalized = query?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return notes;
    return notes
        .where((note) =>
            note.title.toLowerCase().contains(normalized) ||
            note.bodyMarkdown.toLowerCase().contains(normalized) ||
            note.tags.any((tag) => tag.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }

  @override
  Future<List<KnowledgeNote>> searchNotes(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return loadNotes();
    return _activeNotes
        .where((note) =>
            note.title.toLowerCase().contains(normalized) ||
            note.bodyMarkdown.toLowerCase().contains(normalized) ||
            note.tags.any((tag) => tag.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }

  @override
  Future<void> saveNote(KnowledgeNote note) async {
    final index = _notes.indexWhere((candidate) => candidate.id == note.id);
    if (index < 0) {
      _notes.add(note);
    } else {
      _notes[index] = note.copyWith(deletedAt: null);
    }
    _owners[note.id] = _ownerUserId;
  }

  @override
  Future<void> applyRemoteNote(KnowledgeNote note) async {
    final index = _notes.indexWhere((candidate) => candidate.id == note.id);
    if (index < 0) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _owners[note.id] = _ownerUserId;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final index = _notes.indexWhere((candidate) => candidate.id == noteId);
    if (index < 0) return;
    final now = DateTime.now().toUtc();
    final existing = _notes[index];
    if (existing.deletedAt == null) {
      _notes[index] = existing.copyWith(
          updatedAt: now, version: existing.version + 1, deletedAt: now);
    }
  }

  List<KnowledgeNote> get _activeNotes =>
      _notes.where((note) => note.deletedAt == null).toList(growable: false);
}

abstract interface class KnowledgeNoteRepository implements NoteRepository {}

class DriftKnowledgeNoteRepository extends DriftNoteRepository
    implements KnowledgeNoteRepository {
  DriftKnowledgeNoteRepository(super.database);
}

class InMemoryKnowledgeNoteRepository extends InMemoryNoteRepository
    implements KnowledgeNoteRepository {
  InMemoryKnowledgeNoteRepository({super.seed});
}
