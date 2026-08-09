class NewsItem {
  const NewsItem(
      {required this.repositoryFullName,
      required this.title,
      required this.summary,
      required this.sourceUrl,
      required this.tags,
      required this.stars,
      required this.forks,
      required this.score,
      this.publishedAt,
      this.fetchedAt,
      this.summaryVersion = 'raw-description'});

  final String repositoryFullName;
  final String title;
  final String summary;
  final String sourceUrl;
  final List<String> tags;
  final int stars;
  final int forks;
  final double score;
  final DateTime? publishedAt;
  final DateTime? fetchedAt;
  final String summaryVersion;

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        repositoryFullName: json['repository_full_name'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        sourceUrl: json['source_url'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        stars: (json['stars'] as num? ?? 0).toInt(),
        forks: (json['forks'] as num? ?? 0).toInt(),
        score: (json['score'] as num? ?? 0).toDouble(),
        publishedAt: _parseDate(json['published_at']),
        fetchedAt: _parseDate(json['fetched_at']),
        summaryVersion: json['summary_version'] as String? ?? 'raw-description',
      );

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
