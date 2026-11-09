import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';

import 'fixtures.dart';

void main() {
  const s = Duration(seconds: 1);
  group('NetworkQuietPolicy.done', () {
    const p = NetworkQuietPolicy.live;
    test('keeps polling while resources keep arriving', () {
      expect(p.done(elapsed: s * 10, sinceLastChange: s * 2), isFalse);
    });
    test('stops 5 s after the last change', () {
      expect(p.done(elapsed: s * 10, sinceLastChange: s * 5), isTrue);
    });
    test('stops at the time limit even while busy (30 s live, 45 s fresh)',
        () {
      expect(p.done(elapsed: s * 30, sinceLastChange: Duration.zero), isTrue);
      expect(
          NetworkQuietPolicy.fresh
              .done(elapsed: s * 30, sinceLastChange: Duration.zero),
          isFalse);
      expect(
          NetworkQuietPolicy.fresh
              .done(elapsed: s * 45, sinceLastChange: Duration.zero),
          isTrue);
    });
    test('off is not enabled', () {
      expect(NetworkQuietPolicy.off.enabled, isFalse);
      expect(p.enabled, isTrue);
    });
  });

  group('resourceSignature', () {
    Present<int> b(int v) => Present(v, source: DataSource.browser);
    test('changes on a new resource and on a grown size only', () {
      final one = Present([res('https://a.test/a.js', tx: b(10))],
          source: DataSource.browser);
      final same = Present([res('https://a.test/a.js', tx: b(10))],
          source: DataSource.browser);
      final grown = Present([res('https://a.test/a.js', tx: b(20))],
          source: DataSource.browser);
      final more = Present([
        res('https://a.test/a.js', tx: b(10)),
        res('https://a.test/b.js'),
      ], source: DataSource.browser);
      expect(resourceSignature(one), resourceSignature(same));
      expect(resourceSignature(one), isNot(resourceSignature(grown)));
      expect(resourceSignature(one), isNot(resourceSignature(more)));
      expect(resourceSignature(const Pending()), -1);
    });
  });
}
