import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/sovereignty_view.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

HostInfo host(String name, {String? country, int requests = 1}) {
  final h = HostInfo(name)..requests = requests;
  if (country != null) h.asnCountry = country;
  return h;
}

SovereigntyReport report(List<HostInfo> hosts,
        {List<SovereigntyCheck> checks = const [], String home = 'EU'}) =>
    SovereigntyReport(
      home: home,
      mainHost: 'a.test',
      hosts: hosts,
      cdn: null,
      nameServers: const [],
      mailServers: const [],
      tlsIssuer: null,
      tlsProvider: null,
      checks: checks,
    );

void main() {
  group('headline', () {
    test('everything in the home jurisdiction', () {
      final s = summarizeSovereignty(report([host('a', country: 'NL')]));
      expect(s.headline, startsWith('All requests stay with companies'));
    });

    test('some outside', () {
      final s = summarizeSovereignty(
          report([host('a', country: 'NL'), host('b', country: 'US')]));
      expect(s.headline, startsWith('50% of requests go to companies outside'));
    });

    test('everything unknown is not "all requests stay"', () {
      final s = summarizeSovereignty(report([host('a'), host('b')]));
      expect(s.headline, isNot(contains('All requests stay')));
      expect(s.headline, contains('could not be determined'));
      expect(s.unknownShare, 1.0);
    });

    test('part unknown: says how much could not be attributed', () {
      final s =
          summarizeSovereignty(report([host('a', country: 'NL'), host('b')]));
      expect(s.headline, contains('50% of requests could not be attributed'));
      expect(s.headline, isNot(startsWith('All requests stay')));
    });

    test('no hosts at all', () {
      expect(
          summarizeSovereignty(report([])).headline, 'No requests to analyse.');
    });
  });

  group('score and pillars', () {
    test('no verifiable check: no score; pillar says not verifiable', () {
      final s = summarizeSovereignty(report([
        host('a')
      ], checks: const [
        SovereigntyCheck(Pillar.security, 'c', CheckStatus.unknown, ''),
      ]));
      expect(s.score, isNull);
      expect(s.grade, isNull);
      expect(s.pillars.every((p) => p.fraction == null), isTrue);
      expect(s.pillars.first.label, 'not verifiable');
      expect(s.pillars.map((p) => p.label), isNot(contains('n/a')));
    });

    test('verified pillar shows points', () {
      final s = summarizeSovereignty(report([
        host('a')
      ], checks: const [
        SovereigntyCheck(Pillar.residency, 'a', CheckStatus.warn, ''),
      ]));
      final residency =
          s.pillars.singleWhere((p) => p.pillar == Pillar.residency);
      expect(residency.label, '13/25');
      expect(residency.fraction, closeTo(0.5, 0.01));
    });
  });
}
