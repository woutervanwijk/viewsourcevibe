import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/page_weight.dart';

void main() {
  const page = 'https://example.com/';

  group('resourcesBySize', () {
    test('sorts largest first, falling back to transfer size', () {
      final result = resourcesBySize([
        {'name': 'https://example.com/a.js', 'transfer': 100, 'decoded': 300},
        {'name': 'https://cdn.com/b.png', 'transfer': 900, 'decoded': 0},
        {'name': 'https://example.com/c.css', 'transfer': 50, 'decoded': 500},
      ], page);

      expect(result.map((r) => r.fileName), ['b.png', 'c.css', 'a.js']);
      expect(result.first.size, 900);
      expect(result.map((r) => r.type), ['image', 'style', 'script']);
    });

    test('skips data URIs and empty names, merges duplicates', () {
      final result = resourcesBySize([
        {'name': 'data:image/png;base64,AAAA', 'transfer': 0, 'decoded': 99},
        {'name': '', 'transfer': 1, 'decoded': 1},
        {'name': 'https://example.com/a.js', 'transfer': 0, 'decoded': 0},
        {'name': 'https://example.com/a.js', 'transfer': 10, 'decoded': 40},
      ], page);

      expect(result, hasLength(1));
      expect(result.single.decoded, 40);
    });

    test('unknown sizes sort last', () {
      final result = resourcesBySize([
        {'name': 'https://x.com/unknown.woff2', 'transfer': 0, 'decoded': 0},
        {'name': 'https://x.com/known.js', 'transfer': 1, 'decoded': 1},
      ], page);

      expect(result.last.fileName, 'unknown.woff2');
    });
  });

  group('ResourceSize', () {
    test('fileName uses last path segment or host', () {
      ResourceSize r(String url) =>
          ResourceSize(url: url, transfer: 0, decoded: 0, type: 'other');

      expect(r('https://example.com/js/app%20main.js?v=1').fileName,
          'app main.js');
      expect(r('https://example.com/').fileName, 'example.com');
      expect(r('https://example.com/').host, 'example.com');
    });
  });
}
