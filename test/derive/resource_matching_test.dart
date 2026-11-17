import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/resource_matching.dart';

void main() {
  group('sameResourceModuloCacheBusters', () {
    test('matches identical URLs', () {
      expect(
        sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
        ),
        isTrue,
      );
    });

    test('ignores cache-buster params like v and cb', () {
      expect(
        sameResourceModuloCacheBusters(
          'https://cdn.example.com/app.js?v=1',
          'https://cdn.example.com/app.js?v=2',
        ),
        isTrue,
      );
      expect(
        sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&cb=aaa',
          'https://i.regiogroei.cloud/a.jpg?cb=bbb&width=112',
        ),
        isTrue,
      );
    });

    test('does not match different resize params on the same path', () {
      expect(
        sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg?width=264&height=148',
        ),
        isFalse,
      );
    });

    test('does not match a resized variant against the unresized original', () {
      expect(
        sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg?width=112&height=64',
          'https://i.regiogroei.cloud/a.jpg',
        ),
        isFalse,
      );
    });

    test('does not match different paths or hosts', () {
      expect(
        sameResourceModuloCacheBusters(
          'https://cdn.example.com/a/app.js',
          'https://cdn.example.com/b/app.js',
        ),
        isFalse,
      );
      expect(
        sameResourceModuloCacheBusters(
          'https://i.regiogroei.cloud/a.jpg',
          'https://s.regiogroei.cloud/a.jpg',
        ),
        isFalse,
      );
    });
  });

  test('queryWithoutCacheBusters is sorted and drops busters', () {
    expect(queryWithoutCacheBusters(Uri.parse('https://a/x?b=2&v=9&a=1')),
        'a=1&b=2');
  });

  group('ResourceSizeIndex', () {
    Map<String, dynamic> e(String name, int tx) => {
          'name': name,
          'transfer': tx,
          'decoded': tx * 3,
          'initiatorType': 'script'
        };

    test('the same filename on another host is not a match', () {
      final i = ResourceSizeIndex([e('https://b.test/y/logo.png', 900)]);
      expect(i.find('https://a.test/x/logo.png'), isNull);
    });
    test('the same filename in another directory is not a match for a script',
        () {
      final i = ResourceSizeIndex([e('https://a.test/b/index.js', 900)]);
      expect(i.find('https://a.test/a/index.js'), isNull);
    });
    test('a size variant of an image is an estimate that names its source', () {
      final i = ResourceSizeIndex([
        {
          ...e('https://img.test/w_400/photo-1.jpg', 700),
          'initiatorType': 'img'
        }
      ]);
      final s = i.find('https://img.test/w_1200/photo-1.jpg')!;
      expect(s['transfer'], 700);
      expect(s['estimated'], isTrue);
      expect(s['variantOf'], 'https://img.test/w_400/photo-1.jpg');
    });
    test('exact and cache-buster matches are not estimates', () {
      final i = ResourceSizeIndex([e('https://a.test/app.js?v=2', 500)]);
      expect(i.find('https://a.test/app.js?v=1'),
          {'transfer': 500, 'decoded': 1500});
    });
    test('data URIs are sized by their own bytes', () {
      expect(
          ResourceSizeIndex(const [])
              .find('data:image/gif;base64,AAAA')!['transfer'],
          26);
    });
  });
}
