import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/block_page.dart';
import 'package:view_source_vibe/services/derive/cookies_view.dart';
import 'package:view_source_vibe/services/derive/detections_view.dart';
import 'package:view_source_vibe/services/derive/divergences.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

import '../fixtures/inspection/bot_blocked.dart';
import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/trackers.dart';

SummaryInputs inputsFor(
  PageInspection p, {
  List<Detection> detections = const [],
  BlockPage? blockPage,
  Observed<SecurityModel>? security,
  Observed<SovereigntyReport>? sovereignty,
  List<Divergence> divergences = const [],
}) {
  final complete = p.target is! NoTarget;
  return SummaryInputs(
    inspection: p,
    general: deriveGeneral(p, divergences: divergences),
    security: security ?? deriveSecurity(p, now: DateTime.utc(2026, 1, 1)),
    cookies: deriveCookiesView(p, now: DateTime.utc(2026, 1, 1)),
    detections: DetectionsView(
      detections: detections,
      scanning: false,
      failure: null,
      sources: CheckedSources(complete ? const ['server HTML'] : const [],
          const [], false),
    ),
    sovereignty: sovereignty ??
        const Unavailable(UnavailableReason.notApplicable, 'none'),
    blockPage: blockPage,
    divergences: divergences,
  );
}

Detection det(String name, {int requests = 0}) =>
    Detection(entityNamed(name)!)..requests = requests;

Observed<SecurityModel> securityWith(List<SecurityCheck> checks) => Present(
    SecurityModel(
      audit: Present(SecurityAudit(checks, const []),
          source: DataSource.server),
      csp: const Unavailable(UnavailableReason.notApplicable),
      certificate: const Unavailable(UnavailableReason.notApplicable),
      tlsWarning: null,
    ),
    source: DataSource.server);

void main() {
  test('trackers are reported with names and severity', () {
    final s = deriveSummary(inputsFor(trackerPage(), detections: [
      det('Google Ads', requests: 2),
      det('Google Analytics', requests: 1),
    ]));
    final f = s.findings.firstWhere((f) => f.id == 'trackers');
    expect(f.severity, FindingSeverity.high);
    expect(f.title, '2 tracker(s): Google Ads, Google Analytics');
    expect(f.tab, 'privacy');
    expect(s.facts['trackers'], 2);
    expect(s.facts['trackerNames'], ['Google Ads', 'Google Analytics']);
  });

  test('more than three trackers are cut with a count', () {
    final s = deriveSummary(inputsFor(trackerPage(), detections: [
      det('Google Ads', requests: 1),
      det('Meta Pixel', requests: 1),
      det('Hotjar', requests: 1),
      det('Google Analytics', requests: 1),
      det('Microsoft Clarity', requests: 1),
    ]));
    final f = s.findings.firstWhere((f) => f.id == 'trackers');
    expect(f.title, '5 tracker(s): Google Ads, Meta Pixel, Hotjar (+2)');
  });

  test('tracking with a consent tool present is pre-consent tracking', () {
    final s = deriveSummary(inputsFor(trackerPage(), detections: [
      det('Google Ads', requests: 2),
      det('Cookiebot', requests: 1),
    ]));
    final f = s.findings.firstWhere((f) => f.id == 'pre-consent');
    expect(f.severity, FindingSeverity.high);
    expect(f.title, contains('Cookiebot'));
    expect(s.facts['consentTool'], 'Cookiebot');
  });

  test('a block page hides content findings', () {
    final s = deriveSummary(inputsFor(botBlocked(),
        blockPage: const BlockPage(status: 403, byMarker: true),
        detections: [det('Google Ads', requests: 2)]));
    expect(s.findings.first.id, 'block-page');
    expect(s.findings.first.title, startsWith('Not the site: '));
    expect(s.findings.map((f) => f.id), isNot(contains('trackers')));
    expect(s.facts['blocked'], isTrue);
    expect(s.facts['trackers'], isNull);
  });

  test('unknown facts are null, never 0', () {
    final s = deriveSummary(inputsFor(const PageInspection.empty()));
    expect(s.findings, isEmpty);
    expect(s.facts.keys, summaryFactKeys);
    expect(s.facts['requests'], isNull);
    expect(s.facts['securityHeadersPct'], isNull);
    expect(s.facts['trackers'], isNull);
    expect(s.facts['blocked'], isNull);
  });

  test('findings are sorted by severity, then rule order', () {
    final s = deriveSummary(inputsFor(trackerPage(),
        detections: [det('Google Ads', requests: 1)],
        security: securityWith(const [
          SecurityCheck('HSTS', true, false, ''),
          SecurityCheck('CSP', true, false, ''),
        ])));
    final ids = s.findings.map((f) => f.id).toList();
    expect(ids, containsAll(['trackers', 'security-headers']));
    final sev = s.findings.map((f) => f.severity.index).toList();
    expect(sev, [...sev]..sort());
    expect(s.top.length, lessThanOrEqualTo(5));
  });

  test('security headers name what is missing', () {
    final s = deriveSummary(inputsFor(fullPage(),
        security: securityWith(const [
          SecurityCheck('HSTS', true, false, ''),
          SecurityCheck('CSP', true, false, ''),
          SecurityCheck('Frames', true, true, ''),
          SecurityCheck('No Sniff', true, true, ''),
          SecurityCheck('Referrer', true, true, ''),
          SecurityCheck('Permissions', true, true, ''),
        ])));
    final f = s.findings.firstWhere((f) => f.id == 'security-headers');
    expect(f.title, 'Security headers: 67% (missing: HSTS, CSP)');
    expect(f.severity, FindingSeverity.low);
    expect(s.facts['securityHeadersPct'], 67);
  });

  test('titles never say unknown and toJson is plain data', () {
    final s = deriveSummary(inputsFor(trackerPage(),
        detections: [det('Google Ads', requests: 1)]));
    for (final f in s.findings) {
      expect(f.title.toLowerCase(), isNot(contains('unknown')));
    }
    final j = s.toJson();
    expect((j['findings'] as List).first, isA<Map<String, Object?>>());
    expect((j['facts'] as Map).keys, summaryFactKeys);
  });

  test('plain http is a high finding', () {
    final p = urlInspection(
      url: 'http://old.example.org/',
      serverResult: server(serverSnapshot(
          url: 'http://old.example.org/',
          hops: [hop('http://old.example.org/', 200)],
          body: '<html></html>')),
      browserResult: const Pending(),
    );
    final s = deriveSummary(inputsFor(p));
    expect(s.findings.first.id, 'no-https');
    expect(s.facts['finalUrl'], 'http://old.example.org/');
    expect(s.facts['status'], 200);
  });
}
