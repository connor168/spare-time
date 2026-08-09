import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/services/github_digest_client.dart';

void main() {
  test('parses digest items from the backend contract', () async {
    final client = GitHubDigestClient(
      endpoint: Uri.parse('https://example.test/digest'),
      get: (uri, headers) async {
        expect(headers['accept'], 'application/json');
        return '{"items":[{"repository_full_name":"openai/demo","title":"demo","summary":"A project","source_url":"https://github.com/openai/demo","tags":["llm"],"stars":12,"forks":3,"score":18.5,"fetched_at":"2026-08-08T00:00:00Z"}]}';
      },
    );
    final items = await client.fetch();
    expect(items.single.repositoryFullName, 'openai/demo');
    expect(items.single.stars, 12);
  });
}
