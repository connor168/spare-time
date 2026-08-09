const _notProvided = Object();

class KnowledgeNote {
  KnowledgeNote({
    required this.id,
    required this.title,
    required this.bodyMarkdown,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.tags = const [],
    this.isFavorite = false,
    this.deletedAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Note ID cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Note title cannot be empty.');
    }
    if (version < 1) {
      throw ArgumentError.value(
          version, 'version', 'Version must be positive.');
    }
  }

  final String id;
  final String title;
  final String bodyMarkdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final List<String> tags;
  final bool isFavorite;
  final DateTime? deletedAt;

  String get preview => bodyMarkdown.replaceAll(RegExp(r'\s+'), ' ').trim();

  KnowledgeNote copyWith({
    String? title,
    String? bodyMarkdown,
    DateTime? updatedAt,
    int? version,
    List<String>? tags,
    bool? isFavorite,
    Object? deletedAt = _notProvided,
  }) {
    return KnowledgeNote(
      id: id,
      title: title ?? this.title,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      deletedAt: identical(deletedAt, _notProvided)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}
