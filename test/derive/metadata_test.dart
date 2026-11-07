import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/metadata.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

import 'fixtures.dart';

// Run the parser inline (no isolate) so the test is quick and deterministic.
Future<Map<String, dynamic>> _inline(String html, String base,
        {Map<String, String>? headers}) =>
    Future.value(extractMetadataSync(html, base, headers: headers));

void main() {
  test('<base href> resolves links', () async {
    final m = await deriveMetadata(
        '<html><head><base href="https://cdn.x/"><link rel="stylesheet" href="s.css">'
            '</head><body><img src="img/a.png"></body></html>',
        'https://a.test/page',
        DataSource.server,
        extractor: _inline);
    expect(m.data['cssLinks'] as List, ['https://cdn.x/s.css']);
    expect((m.data['media']['images'] as List).single['src'],
        'https://cdn.x/img/a.png');
    expect(m.unresolvedLinks, isEmpty);
  });

  test('local file: relative links are unresolved, not https://img/a.png',
      () async {
    final m = await deriveMetadata(
        '<html><head><link rel="stylesheet" href="s.css"></head>'
            '<body><img src="img/a.png"><script src="https://x.test/a.js"></script></body></html>',
        '',
        DataSource.file,
        extractor: _inline);
    expect(m.unresolvedLinks.map((l) => l.url),
        containsAll(['img/a.png', 's.css']));
    expect(m.unresolvedLinks.first.reason, 'relative link in local file');
    expect(m.unresolvedLinks.map((l) => l.url),
        isNot(contains('https://x.test/a.js')));
    expect(m.data.toString(), isNot(contains('https://img/')));
    expect(m.data['unresolvedLinks'], isNotEmpty);
  });

  test('canonical is filled from <link rel=canonical>', () async {
    final m = await deriveMetadata(
        '<html><head><link rel="canonical" href="/c"></head></html>',
        'https://a.test/page',
        DataSource.browser,
        extractor: _inline);
    expect(m.canonical, 'https://a.test/c');
    expect(m.data['canonical'], 'https://a.test/c');
  });

  test('records the document it ran on', () async {
    final m = await deriveMetadata(
        '<html></html>', 'https://a.test/', DataSource.browser,
        extractor: _inline);
    expect(m.docSource, DataSource.browser);
    expect(m.data['docSource'], 'browser');
  });

  test('primaryDocumentInput follows the inspection', () {
    final both = inspection(
        server: serverSnap(body: '<html>S</html>'),
        browser: browserSnap(dom: '<html>D</html>'));
    final d = primaryDocumentInput(both)!;
    expect(d.text, '<html>D</html>');
    expect(d.source, DataSource.browser);
    expect(d.baseUrl, 'https://a.test/page');
    final serverOnly = inspection(server: serverSnap(body: '<html>S</html>'));
    expect(primaryDocumentInput(serverOnly)!.source, DataSource.server);
    expect(primaryDocumentInput(inspection()), isNull);
  });

  test('viewport / theme-color / msapplication are not links (I1)', () async {
    final m = await deriveMetadata(
        '<html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
            '<meta name="theme-color" content="#fff">'
            '<meta name="msapplication-TileColor" content="#da532c">'
            '<link rel="manifest" href="site.webmanifest"></head></html>',
        '',
        DataSource.file,
        extractor: _inline);
    expect(m.unresolvedLinks.map((l) => l.url), ['site.webmanifest']);
  });
}
