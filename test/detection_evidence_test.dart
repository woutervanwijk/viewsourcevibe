import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

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
    final detections = {
      for (final d in Detection.listFrom(metadata['detections'])) d.name: d
    };

    final ga = detections['Google Analytics']!.evidence.single;
    expect(ga.kind, EvidenceKind.html);
    expect(ga.line, 6);
    expect(ga.detail,
        contains('<script async src="https://www.googletagmanager.com'));
    expect(detections['Meta Pixel']!.evidence.single.line, 7);
    expect(detections, isNot(contains('Google Tag Manager')));

    final wordpress = detections['WordPress']!;
    expect(wordpress.version, '6.4.2');
    expect(wordpress.evidence.first.line, 4); // generator meta tag
    final nginx = detections['Nginx']!.evidence.single;
    expect(nginx.kind, EvidenceKind.header);
    expect(nginx.detail, 'Server: nginx/1.25');
  });

  test('requests and cookies add evidence to source detections', () {
    final ds = detect(
      pageUrl: 'https://example.com/',
      html: _html,
      requests: ['https://www.googletagmanager.com/gtag/js?id=G-1'],
      cookies: [
        {
          'name': '_fbp',
          'domain': '.example.com',
          'category': 'advertising',
          'provider': 'Facebook',
          'source': 'Browser',
        }
      ],
    );

    final ga = ds.firstWhere((d) => d.name == 'Google Analytics');
    expect(ga.requests, 1);
    final request =
        ga.evidence.firstWhere((e) => e.kind == EvidenceKind.request);
    expect(request.line, 6);

    final meta = ds.firstWhere((d) => d.name == 'Meta Pixel');
    expect(meta.evidence.map((e) => e.kind),
        [EvidenceKind.html, EvidenceKind.cookie]);
    expect(meta.evidence.last.detail,
        contains('set by page script (document.cookie)'));
  });
}
