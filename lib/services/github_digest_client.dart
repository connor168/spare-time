import 'dart:convert';
import 'dart:io';

import '../domain/news_item.dart';

typedef JsonGet = Future<String> Function(Uri uri, Map<String, String> headers);

class GitHubDigestClient {
  GitHubDigestClient({required this.endpoint, JsonGet? get, this.accessToken})
      : _get = get ?? _defaultGet;

  final Uri endpoint;
  final String? accessToken;
  final JsonGet _get;

  Future<List<NewsItem>> fetch() async {
    final headers = <String, String>{'accept': 'application/json'};
    if (accessToken case final token? when token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }
    final payload = jsonDecode(await _get(endpoint, headers));
    final items =
        payload is List ? payload : (payload as Map<String, dynamic>)['items'];
    if (items is! List) {
      throw const FormatException(
          'Digest response must contain an items array.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(NewsItem.fromJson)
        .where((item) => item.sourceUrl.isNotEmpty)
        .toList(growable: false);
  }

  static Future<String> _defaultGet(
      Uri uri, Map<String, String> headers) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Digest endpoint returned ${response.statusCode}.',
            uri: uri);
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}
