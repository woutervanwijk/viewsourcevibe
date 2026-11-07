import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot, localFile;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late HtmlService service;

  setUp(() {
    fetcher = FakeServerFetcher();
    service = HtmlService(
      store: InspectionStore(),
      serverFetcher: fetcher,
      browserLoader: FakeBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {'title': html},
    )..setAppSettings(AppSettings()..useBrowserByDefault = false);
  });

  tearDown(() => service.dispose());

  test('R4: detections after a local file carry nothing from the old URL',
      () async {
    final load = service.loadUrl('https://a.test/');
    await pumpEventQueue();
    fetcher.pending.single.complete(okSnapshot('https://a.test/',
        '<html><script src="https://www.googletagmanager.com/gtm.js?id=GTM-1"></script></html>'));
    await load;
    expect(service.detections, isNotEmpty);

    await service.loadFile(localFile('b.html', '<html>plain</html>'));
    expect(service.detections, isEmpty);
    expect(service.divergences, isEmpty);
  });

  test('metadata records the document it ran on', () async {
    await service.loadFile(localFile('b.html', '<html>plain</html>'));
    await pumpEventQueue();
    expect(service.pageMetadata?['docSource'], DataSource.file.name);
  });
}
