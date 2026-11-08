import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/browser_view.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

// The WebView itself cannot run in a widget test; what the BrowserView
// decides from the store is tested here.
void main() {
  test('RSS/Atom content types are feeds', () {
    expect(isFeedContentType('application/rss+xml; charset=utf-8'), isTrue);
    expect(isFeedContentType('Application/Atom+XML'), isTrue);
    expect(isFeedContentType('text/html'), isFalse);
    expect(isFeedContentType(null), isFalse);
  });

  test('the content type comes from the store, not from a file map', () {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    expect(service.serverContentType, 'text/html; charset=utf-8');

    seedStore(
        service.store,
        urlInspection(
            url: 'https://feed.test/',
            serverResult: server(serverSnapshot(
                url: 'https://feed.test/',
                hops: [
                  hop('https://feed.test/', 200, headers: {
                    'content-type': ['application/atom+xml']
                  })
                ],
                body: '<feed/>')),
            browserResult: const Pending()));
    expect(isFeedContentType(service.serverContentType), isTrue);
  });

  test('unknown content type is null (pending server, local file)', () {
    final store = InspectionStore();
    final service = makeService(store);
    addTearDown(service.dispose);
    seedStore(
        store,
        PageInspection(
            generation: 1,
            target: fullPage().target,
            server: const Pending(),
            browser: const Pending(),
            file: const Unavailable(UnavailableReason.notApplicable)));
    expect(service.serverContentType, isNull);
    seedStore(store, localFile());
    expect(service.serverContentType, isNull);
  });
}
