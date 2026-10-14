import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';
import 'package:view_source_vibe/services/tracker_detector.dart';

const _html = '''<!doctype html>
<html>
<head>
<meta name="generator" content="WordPress 6.4.2">
<link rel="stylesheet" href="/wp-content/themes/x/style.css">
<script async src="https://www.googletagmanager.com/gtag/js?id=G-1"></script>
<script>fbq('init', '123');</script>
</head>
<body></body>
</html>''';

void main() {
  test('records line and tag for detected services and technologies', () async {
    final metadata = await extractMetadataInIsolate(
        _html, 'https://example.com/',
        headers: {'server': 'nginx/1.25'});

    final services = DetectionEvidence.mapFrom(metadata['serviceEvidence']);
    final ga = services['Google Analytics']!.single;
    expect(ga.kind, EvidenceKind.html);
    expect(ga.line, 6);
    expect(ga.detail,
        contains('<script async src="https://www.googletagmanager.com'));
    expect(services['Facebook Pixel']!.single.line, 7);

    final tech = DetectionEvidence.mapFrom(metadata['techEvidence']);
    expect(tech['CMS']!.single.line, 4); // generator meta tag
    expect(tech['WordPress Version']!.single.line, 4);
    expect(tech['Web Server']!.single.kind, EvidenceKind.header);
    expect(tech['Web Server']!.single.detail, 'Server: nginx/1.25');
  });

  test('tracker hits carry request, cookie and source evidence', () {
    final hits = detectTrackers(
      pageUrl: 'https://example.com/',
      resourceUrls: ['https://www.googletagmanager.com/gtag/js?id=G-1'],
      cookies: [
        {
          'name': '_fbp',
          'domain': '.example.com',
          'category': 'advertising',
          'provider': 'Facebook',
          'source': 'Browser',
        }
      ],
      services: {
        'Analytics & Trackers': ['Facebook Pixel']
      },
      serviceEvidence: {
        'Facebook Pixel': [
          const DetectionEvidence(EvidenceKind.html, 'HTML line 7', line: 7)
        ]
      },
      html: _html,
    );

    final gtm = hits.firstWhere((h) => h.name == 'Google Tag Manager');
    expect(gtm.evidence.single.kind, EvidenceKind.request);
    expect(gtm.evidence.single.line, 6);

    final meta = hits.firstWhere((h) => h.name == 'Meta Pixel');
    expect(meta.evidence.map((e) => e.kind),
        [EvidenceKind.cookie, EvidenceKind.html]);
    expect(meta.evidence.first.detail,
        contains('set by page script (document.cookie)'));
  });

  test('ignores trackers that are commented out', () async {
    final metadata = await extractMetadataInIsolate(
        '<html><head><!-- <script src="https://www.google-analytics.com/analytics.js"></script> --></head></html>',
        'https://example.com/');
    expect(
        metadata['detectedServices'], isNot(contains('Analytics & Trackers')));
  });

  test('ignores services only mentioned in visible text', () async {
    final metadata = await extractMetadataInIsolate(
        '<html><body><div>doubleclick.net plaatst deze cookie</div></body></html>',
        'https://example.com/');
    expect(metadata['detectedServices'], isNot(contains('Advertising')));
  });

  test('ignores hostnames listed as quoted data in scripts', () async {
    final metadata = await extractMetadataInIsolate(
        '<html><script>{"uris":["dms.netmng.com","doubleclick.net"]}</script></html>',
        'https://example.com/');
    expect(metadata['detectedServices'], isNot(contains('Advertising')));
  });

  test('a site is not its own tracker', () {
    final hits = detectTrackers(
      pageUrl: 'https://www.instagram.com/',
      resourceUrls: ['https://static.cdninstagram.com/app.js'],
      cookies: const [],
    );
    expect(hits, isEmpty);
  });
}
