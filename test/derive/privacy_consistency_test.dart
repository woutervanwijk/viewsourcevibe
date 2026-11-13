// The same trackers must be told the same way on every page that shows
// them: the Cookie Privacy Lens (Security tab), Services/Privacy
// (detections) and the Sovereignty privacy pillar.
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/cookies_view.dart';
import 'package:view_source_vibe/services/derive/detections.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

import '../fixtures/inspection/builders.dart';

const _url = 'https://news.example.com/';
const _html = '<html><head><title>News</title>'
    '<script src="https://www.googletagmanager.com/gtag/js?id=G-TEST1"></script>'
    '<script src="https://consent.cookiebot.com/uc.js"></script>'
    '<script src="https://platform.twitter.com/widgets.js"></script>'
    '</head><body>News</body></html>';

/// A news page with trackers seen three ways: in the source, as requests
/// and as first-party cookies (catalogued, Open Cookie Database only, and
/// the site's own).
PageInspection _page() {
  final h = hop(_url, 200, headers: {
    'content-type': ['text/html; charset=utf-8']
  }, setCookies: [
    '_ga=GA1.1.1.1; Domain=.news.example.com; Path=/; Secure; SameSite=Lax',
    '_fbp=fb.1.1.1; Domain=.news.example.com; Path=/; Secure; SameSite=Lax',
    '_gcl_au=1.1.1.1; Domain=.news.example.com; Path=/; Secure',
    '_hjSessionUser_123=x; Path=/; Secure',
    '_pk_id.1.abcd=x; Path=/; Secure',
    'cto_bundle=x; Path=/; Secure',
    'sessionid=x; Path=/; Secure; HttpOnly',
  ]);
  return urlInspection(
    url: _url,
    serverResult:
        server(serverSnapshot(url: _url, hops: [h], body: _html)),
    browserResult: browser(browserSnapshot(
      url: _url,
      dom: _html,
      resources: [
        resource('https://connect.facebook.net/en_US/fbevents.js', 'script'),
        resource('https://www.google-analytics.com/g/collect?v=2', 'beacon'),
        resource('https://static.hotjar.com/c/hotjar-1.js', 'script'),
      ],
      cookies: const [],
    )),
  );
}

CookiesModel _lens(PageInspection p) =>
    (deriveCookiesView(p) as Present<CookiesModel>).value;

List<SovereigntyCheck> _privacy(List<Detection> d) =>
    SovereigntyService.privacyChecks(const [], d, _html, eu);

/// The names in a Sovereignty check's evidence ("A, B" or "None detected").
Set<String> _evidenceNames(SovereigntyCheck c) => c.evidence ==
        'None detected'
    ? {}
    : c.evidence.split(', ').map((s) => s.trim()).toSet();

const _trackerCookieCategories = {'advertising', 'analytics', 'social'};

void main() {
  final page = _page();
  final lens = _lens(page);
  final detections = deriveDetections(page);
  final privacy = _privacy(detections);

  test('the fixture has tracker cookies, tracker detections and consent', () {
    expect(lens.rows.where((r) => _trackerCookieCategories.contains(r.category)),
        hasLength(greaterThanOrEqualTo(4)));
    expect(detections.where((d) => d.category.isTracking),
        hasLength(greaterThanOrEqualTo(3)));
    expect(detections.any((d) => d.category == DetectionCategory.consent),
        isTrue);
  });

  test('every tracking cookie in the Cookie Lens is a Services detection', () {
    for (final row in lens.rows) {
      if (!_trackerCookieCategories.contains(row.category) ||
          row.provider == null) {
        continue;
      }
      final owner = detections.where((d) => d.cookies.contains(row.name));
      expect(owner, isNotEmpty,
          reason: '${row.name} (${row.category}, ${row.provider}) is in the '
              'Cookie Lens but no service on Services/Privacy claims it');
    }
  });

  test('a tracking cookie and its service agree on the kind of tracking', () {
    for (final d in detections) {
      for (final name in d.cookies) {
        final row = lens.rows.firstWhere((r) => r.name == name);
        if (!_trackerCookieCategories.contains(row.category)) continue;
        expect(d.category.isTracking, isTrue,
            reason: '$name is ${row.category} in the Cookie Lens but '
                '${d.name} is ${d.category.label} on Services');
      }
    }
  });

  test('the site\'s own cookie is not a tracker anywhere', () {
    final own = lens.rows.firstWhere((r) => r.name == 'sessionid');
    expect(_trackerCookieCategories, isNot(contains(own.category)));
    expect(detections.any((d) => d.cookies.contains('sessionid')), isFalse);
  });

  test('Sovereignty counts the trackers that the Privacy tab lists', () {
    final listed = {
      for (final d in detections)
        if (d.category.isTracking) d.name
    };
    final check = privacy.firstWhere((c) => c.title == 'Number of trackers');
    expect(_evidenceNames(check), listed);
  });

  test('the Privacy tab and Sovereignty give the same tracker count', () {
    final privacyTab = detections.where((d) => d.category.isTracking).length;
    final check = privacy.firstWhere((c) => c.title == 'Number of trackers');
    // Social widgets are trackers on both pages (decided 2026-11-13).
    expect(_evidenceNames(check).length, privacyTab);
  });

  test('a social widget is judged once in Sovereignty, as a tracker', () {
    final social = detections
        .where((d) => d.category == DetectionCategory.social)
        .map((d) => d.name)
        .toList();
    expect(social, isNotEmpty);
    final mentions = privacy
        .where((c) => social.any((n) => c.evidence.contains(n)))
        .map((c) => c.title)
        .toSet();
    expect(mentions, isNot(contains(startsWith('Payments'))));
  });

  // Validation run 2026-11-13 (allbirds.com): Google Ads had 12 request
  // evidence items, so its _gcl_au cookie was not in the export.
  test('the export names every cookie a service set, past the evidence cap',
      () {
    final d = Detection(entityNamed('Google Ads')!)..cookies.add('_gcl_au');
    for (var i = 0; i < 20; i++) {
      d.add(DetectionEvidence(EvidenceKind.request, 'Request $i'));
    }
    final map = d.toMap();
    expect(map['cookies'], ['_gcl_au']);
    expect(Detection.fromMap(map)!.cookies, {'_gcl_au'});
  });

  test('a detected consent tool is the one Sovereignty names', () {
    final consent = {
      for (final d in detections)
        if (d.category == DetectionCategory.consent) d.name
    };
    final check = privacy.firstWhere((c) => c.title == 'Consent management');
    expect(check.status, CheckStatus.pass);
    expect(_evidenceNames(check), consent);
  });
}
