import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/site_data_cleaner.dart';

import '../fixtures/inspection/pump.dart';

HtmlFile _file(String path, {bool isUrl = true}) => HtmlFile(
      name: 'index.html',
      path: path,
      content: '<html><body>hi</body></html>',
      lastModified: DateTime(2026),
      size: 28,
      isUrl: isUrl,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('siteDataRecordMatches', () {
    test('matches the domain itself and its subdomains', () {
      expect(siteDataRecordMatches('w3.org', 'w3.org'), isTrue);
      expect(siteDataRecordMatches('www.w3.org', 'w3.org'), isTrue);
      expect(siteDataRecordMatches('WWW.W3.ORG', 'w3.org'), isTrue);
    });

    test('does not match other sites that only share a suffix', () {
      expect(siteDataRecordMatches('notw3.org', 'w3.org'), isFalse);
      expect(siteDataRecordMatches('w3.org', 'example.com'), isFalse);
      expect(siteDataRecordMatches('w3.org', null), isFalse);
      expect(siteDataRecordMatches('w3.org', ''), isFalse);
    });
  });

  group('reloadWithClearedSiteData', () {
    HtmlService make(List<Uri> cleared) => HtmlService(
          store: InspectionStore(),
          serverFetcher: SilentServerFetcher(),
          browserLoader: SilentBrowserLoader(),
          metadataExtractor: (html, base, {headers}) async => {},
          clearSiteData: (url) async => cleared.add(url),
        );

    test('clears the open site, then reloads it', () async {
      final cleared = <Uri>[];
      final service = make(cleared);
      addTearDown(service.dispose);
      await service.loadFile(_file('https://www.w3.org/standards/'));

      final host = await service.reloadWithClearedSiteData();

      expect(host, 'www.w3.org');
      expect(cleared, [Uri.parse('https://www.w3.org/standards/')]);
      expect(service.currentInputText, 'https://www.w3.org/standards/');
    });

    test('a local file is only reloaded, nothing is cleared', () async {
      final cleared = <Uri>[];
      final service = make(cleared);
      addTearDown(service.dispose);
      await service.loadFile(_file('', isUrl: false));

      expect(await service.reloadWithClearedSiteData(), isNull);
      expect(cleared, isEmpty);
    });

    test('nothing open: nothing happens', () async {
      final cleared = <Uri>[];
      final service = make(cleared);
      addTearDown(service.dispose);

      expect(await service.reloadWithClearedSiteData(), isNull);
      expect(cleared, isEmpty);
    });
  });
}
