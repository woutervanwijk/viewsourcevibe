import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/tracker_detector.dart';

void main() {
  test('groups resources and cookies per tracker, ignoring first party', () {
    final hits = detectTrackers(
      pageUrl: 'https://www.example.com/',
      resourceUrls: [
        'https://www.google-analytics.com/analytics.js',
        'https://www.google-analytics.com/collect',
        'https://static.hotjar.com/c/hotjar.js',
        'https://cdn.example.com/app.js',
        'data:image/png;base64,AAAA',
      ],
      cookies: [
        {
          'name': '_ga',
          'domain': '.example.com',
          'category': 'analytics',
          'provider': 'Google Analytics'
        },
        {
          'name': 'x',
          'domain': 'foo.com',
          'category': 'advertising',
          'provider': 'SomeAdCo'
        },
        {
          'name': 'sess',
          'domain': 'example.com',
          'category': 'essential',
          'provider': 'Shopify'
        },
      ],
    );

    expect(hits.map((h) => h.name), ['SomeAdCo', 'Hotjar', 'Google Analytics']);
    final ga = hits.firstWhere((h) => h.name == 'Google Analytics');
    expect(ga.requests, 2);
    expect(ga.cookies, {'_ga'});
  });
}
