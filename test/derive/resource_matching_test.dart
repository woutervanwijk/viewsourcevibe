import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';

void main() {
  group('HtmlService.sameResourceModuloCacheBusters', () {
    test('matches identical URLs', () {
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
        ),
        isTrue,
      );
    });

    test('ignores cache-buster params like v and cb', () {
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://cdn.example.com/app.js?v=1',
          'https://cdn.example.com/app.js?v=2',
        ),
        isTrue,
      );
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&cb=aaa',
          'https://i.regiogroei.cloud/a.jpg?cb=bbb&width=112',
        ),
        isTrue,
      );
    });

    test('does not match different resize params on the same path', () {
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg?width=264&height=148',
        ),
        isFalse,
      );
    });

    test('does not match a resized variant against the unresized original', () {
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg',
        ),
        isFalse,
      );
    });

    test('does not match different paths or hosts', () {
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://cdn.example.com/a/app.js',
          'https://cdn.example.com/b/app.js',
        ),
        isFalse,
      );
      expect(
        HtmlService.sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg',
          'https://s.regiogroei.cloud/a.jpg',
        ),
        isFalse,
      );
    });
  });
}
