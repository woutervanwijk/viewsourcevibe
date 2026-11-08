import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/detections.dart';
import '../derive/fixtures.dart';
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
  late InspectionStore store;
  var scans = 0;

  setUp(() {
    fetcher = FakeServerFetcher();
    store = InspectionStore();
    scans = 0;
    service = HtmlService(
      store: store,
      detectionScanner: (texts) async {
        scans++;
        return scanTextsToMaps(texts);
      },
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
    service.detections;
    await pumpEventQueue();
    expect(service.detections, isNotEmpty);

    await service.loadFile(localFile('b.html', '<html>plain</html>'));
    service.detections;
    await pumpEventQueue();
    expect(service.detections, isEmpty);
    expect(service.detectionsPending, isFalse);
    expect(service.divergences, isEmpty);
  });

  test('metadata records the document it ran on', () async {
    await service.loadFile(localFile('b.html', '<html>plain</html>'));
    await pumpEventQueue();
    expect(service.pageMetadata?['docSource'], DataSource.file.name);
  });

  test('a resources-only update does not re-run the text scan (I2)', () async {
    final load = service.loadUrl('https://a.test/');
    await pumpEventQueue();
    fetcher.pending.single.complete(okSnapshot('https://a.test/',
        '<html><script src="https://connect.facebook.net/en_US/fbevents.js"></script></html>'));
    await load;
    service.detections;
    await pumpEventQueue();
    expect(service.detections, isNotEmpty);
    expect(scans, 1);

    store.applyBrowser(
        store.current.generation,
        browserSnap(url: 'https://a.test/', dom: null, resources: [
          res('https://www.google-analytics.com/g/collect?v=2')
        ]));
    final after = service.detections;
    await pumpEventQueue();
    expect(scans, 1);
    expect(after.any((d) => d.requests > 0), isTrue);
  });

  test('large text is scanned off-thread: pending, then notifies (I2)',
      () async {
    final big = HtmlService(
      store: InspectionStore(),
      serverFetcher: fetcher,
      browserLoader: FakeBrowserLoader(),
      detectionIsolateThreshold: 10,
      metadataExtractor: (html, baseUrl, {headers}) async => {},
    )..setAppSettings(AppSettings()..useBrowserByDefault = false);
    addTearDown(big.dispose);
    await big.loadFile(localFile('b.html',
        '<html><script src="https://connect.facebook.net/en_US/fbevents.js"></script></html>'));
    var notified = 0;
    big.addListener(() => notified++);
    expect(big.detections, isEmpty);
    expect(big.detectionsPending, isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(big.detectionsPending, isFalse);
    expect(notified, greaterThan(0));
    expect(big.detections, isNotEmpty);
  });
}
