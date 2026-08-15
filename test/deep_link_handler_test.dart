import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/services/deep_link_handler.dart';

void main() {
  test('recognizes the daily news route', () {
    expect(
      DeepLinkHandler.parse('focusflow://news/daily'),
      DeepLinkRoute.newsDaily,
    );
    expect(
      DeepLinkHandler.parse('focusflow://news/daily/2026-08-15'),
      DeepLinkRoute.newsDaily,
    );
  });

  test('rejects unrelated Focus Flow routes', () {
    expect(
      DeepLinkHandler.parse('focusflow://open'),
      DeepLinkRoute.unknown,
    );
    expect(
      DeepLinkHandler.parse('https://example.com/news/daily'),
      DeepLinkRoute.unknown,
    );
  });

  test('treats malformed input as unknown', () {
    expect(DeepLinkHandler.parse('http://['), DeepLinkRoute.unknown);
  });
}
