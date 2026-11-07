import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/cookies_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import 'fixtures.dart';

CookiesModel cookies(PageInspection p) =>
    (deriveCookiesView(p, now: DateTime.utc(2026, 1, 1))
            as Present<CookiesModel>)
        .value;

void main() {
  group('states', () {
    test('local file and nothing loaded', () {
      expect((deriveCookiesView(localFile()) as Unavailable).detail,
          contains('local file'));
      expect(
          (deriveCookiesView(const PageInspection.empty()) as Unavailable)
              .detail,
          'Probe a URL to see details');
    });

    test('both sources still loading: pending', () {
      final p = fullPage()
          .copyWith(server: const Pending(), browser: const Pending());
      expect(deriveCookiesView(p), isA<Pending<CookiesModel>>());
    });

    test('server failed and no browser cookies: the error', () {
      final p = fullPage().copyWith(
          server: const Failed('network error: boom'),
          browser: const Pending());
      expect((deriveCookiesView(p) as Failed).error, 'network error: boom');
    });

    test('no source has cookies and none is pending: unavailable', () {
      final p = inspection(browser: browserSnap(cookies: null));
      final o = deriveCookiesView(p.copyWith(
          server: const Unavailable(UnavailableReason.notApplicable, 'x')));
      expect(o, isA<Unavailable<CookiesModel>>());
    });

    test('one source missing is said, not hidden', () {
      final p = fullPage().copyWith(browser: const Pending());
      final m = cookies(p);
      expect(m.sourcesNote, contains('browser'));
      expect(m.complete, isFalse);
    });

    test('no cookies at all with every source present is an honest zero', () {
      final p = inspection(
          server: serverSnap(), browser: browserSnap(cookies: const []));
      final m = cookies(p);
      expect(m.rows, isEmpty);
      expect(m.complete, isTrue);
      expect(m.score, 100);
    });

    test('no cookies but a source unknown: no score', () {
      final p = inspection(server: serverSnap(), browser: browserSnap());
      final m = cookies(p);
      expect(m.rows, isEmpty);
      expect(m.complete, isFalse);
      expect(m.score, isNull);
    });
  });

  group('flags', () {
    test('browser cookie with unknown flags says unknown, never No', () {
      final p = inspection(
          server: serverSnap(), browser: browserSnap(cookies: [cookie('x')]));
      final c = cookies(p).rows.single;
      expect(c.secure, 'unknown');
      expect(c.httpOnly, 'unknown');
      expect(c.sameSite, 'unknown');
      expect(c.flagsLine,
          'Secure: unknown · HttpOnly: unknown · SameSite: unknown');
      expect(c.domain, 'unknown');
      expect(c.expires, 'unknown');
      expect(c.source, 'Browser');
    });

    test('server cookie: absent flags are known to be absent', () {
      final p = inspection(
          server: serverSnap(
              setCookies: ['sid=abc; Path=/; HttpOnly'],
              url: 'https://a.test/page'),
          browser: browserSnap(cookies: const []));
      final c = cookies(p).rows.single;
      expect(c.secure, 'no');
      expect(c.httpOnly, 'yes');
      expect(c.sameSite, 'not set');
      expect(c.domain, 'a.test (host-only)');
      expect(c.path, '/');
      expect(c.expires, 'session');
      expect(c.source, 'Server');
      expect(c.valueBytes, 3);
    });

    test('the full-page fixture cookie', () {
      final c = cookies(fullPage()).rows.single;
      expect(c.name, 'sid');
      expect(c.secure, 'yes');
      expect(c.httpOnly, 'yes');
      expect(c.sameSite, 'Lax');
      expect(c.domain, 'example.com');
      expect(c.expires, 'unknown');
      expect(c.source, 'Browser');
    });
  });

  group('privacy lens', () {
    test('counts only what is known', () {
      final p = inspection(
          server: serverSnap(setCookies: [
            '_ga=1; Path=/',
            'sid=2; Secure; HttpOnly; SameSite=Lax'
          ]),
          browser: browserSnap(cookies: [cookie('u')]));
      final m = cookies(p);
      expect(m.total, 3);
      expect(m.secureCount, 1);
      expect(m.unknownSecureCount, 1);
      expect(m.httpOnlyCount, 1);
      expect(m.analyticsCount, 1);
      expect(m.score, lessThan(100));
      expect(m.verdict, isNotEmpty);
      expect(m.notes.map((n) => n.text).join(' '),
          contains('1 analytics cookie can measure repeat visits.'));
    });

    test('unknown flags are not penalised as missing', () {
      final p = inspection(
          server: serverSnap(), browser: browserSnap(cookies: [cookie('u')]));
      final m = cookies(p);
      expect(m.notes.map((n) => n.text).join(' '),
          isNot(contains('not marked Secure')));
    });

    test('rows: known providers first, then by name', () {
      final p = inspection(
          server: serverSnap(setCookies: ['zzz=1', '_ga=1', 'aaa=1']),
          browser: browserSnap(cookies: const []));
      expect(cookies(p).rows.map((r) => r.name), ['_ga', 'aaa', 'zzz']);
    });
  });
}
