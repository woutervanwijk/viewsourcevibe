import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:view_source_vibe/services/logo_service.dart';

void main() {
  test('resolves logo domains for technologies, services and trackers', () {
    expect(logoDomainFor('WordPress'), 'wordpress.org');
    expect(logoDomainFor('Bootstrap 5.3'), 'getbootstrap.com');
    expect(logoDomainFor('Google Fonts'), 'www.google.com');
    expect(logoDomainFor('Facebook Pixel'), 'facebook.com');
    expect(logoDomainFor('Google Analytics'), 'marketingplatform.google.com');
    expect(logoDomainFor('Some Unknown Thing'), isNull);
  });
  _logoRetryTests();
}

class _Net {
  final List<int> statuses;
  int calls = 0;
  _Net(this.statuses);
  Future<http.Response> get(Uri url) async {
    final status =
        statuses[calls < statuses.length ? calls : statuses.length - 1];
    calls++;
    if (status < 0) throw Exception('offline');
    return http.Response('PNGDATA', status);
  }
}

void _logoRetryTests() {
  group('LogoService failure caching (B35)', () {
    late DateTime now;
    setUp(() {
      now = DateTime(2026, 1, 1, 12);
      LogoService.resetForTest(clock: () => now);
    });
    tearDown(() => LogoService.resetForTest());

    test('a non-200 answer is not retried for 5 minutes, then it is', () async {
      final net = _Net([404, 200]);
      LogoService.httpGetForTest = net.get;
      expect(await LogoService.load('a.test'), isNull);
      expect(net.calls, 1);

      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(await LogoService.load('a.test'), isNull);
      expect(net.calls, 1, reason: 'still inside the 5 minute window');

      now = now.add(const Duration(seconds: 2));
      final bytes = await LogoService.load('a.test');
      expect(net.calls, 2);
      expect(bytes, isNotNull);
      expect(LogoService.cached('a.test'), isNotNull);
    });

    test('an error is not retried immediately, and is retried after 5 minutes',
        () async {
      final net = _Net([-1, 200]);
      LogoService.httpGetForTest = net.get;
      expect(await LogoService.load('b.test'), isNull);
      expect(await LogoService.load('b.test'), isNull);
      expect(net.calls, 1);
      now = now.add(const Duration(minutes: 5));
      expect(await LogoService.load('b.test'), isNotNull);
      expect(net.calls, 2);
    });

    test('a success is kept for the session', () async {
      final net = _Net([200]);
      LogoService.httpGetForTest = net.get;
      await LogoService.load('c.test');
      now = now.add(const Duration(hours: 3));
      await LogoService.load('c.test');
      expect(net.calls, 1);
    });

    test('other domains are not blocked by a failure', () async {
      final net = _Net([404, 200]);
      LogoService.httpGetForTest = net.get;
      expect(await LogoService.load('d.test'), isNull);
      expect(await LogoService.load('e.test'), isNotNull);
    });
  });
}
