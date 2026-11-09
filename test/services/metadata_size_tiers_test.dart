import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_browser_sync_test.dart' show obs, payload;
import 'html_service_lifecycle_test.dart'
    show FakeBrowserLoader, FakeServerFetcher, okSnapshot;

/// The size-matching tiers of the metadata enrichment: each declared link
/// must find its resource's size through the same tier as before the
/// timeline got indexed (exact, URL-normalised, cache-buster query,
/// filename+query, image variant), and a link that matches nothing gets
/// no size at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeServerFetcher fetcher;
  late FakeBrowserLoader loader;
  late InspectionStore store;
  late HtmlService service;

  setUp(() {
    fetcher = FakeServerFetcher();
    loader = FakeBrowserLoader();
    store = InspectionStore();
  });

  tearDown(() {
    service.dispose();
    store.dispose();
  });

  test('each tier still matches, in order; no match means no size', () async {
    service = HtmlService(
      store: store,
      serverFetcher: fetcher,
      browserLoader: loader,
      metadataExtractor: (html, baseUrl, {headers}) async => <String, dynamic>{
        'jsLinks': <dynamic>[
          'https://cdn.test/exact.js', // tier 1: exact
          'https://cdn.test/dir/', // tier 2: resource is /dir (trailing /)
          'https://cdn.test/cached.js?v=1', // tier 3: resource ?v=2 (cache-buster)
          'https://a.test/deep/chunk.js', // tier 4: other host, same filename
        ],
        'media': <String, dynamic>{
          'images': <dynamic>[
            // tier 5: same host + filename, different path variant, but the
            // query differs so tier 4 must not fire first
            <String, dynamic>{'src': 'https://img.test/img/123/0.50/slug.jpg?w=100'},
            // no tier matches: different host AND different filename
            <String, dynamic>{'src': 'https://other.test/thumb.jpg?width=112'},
          ],
        },
      },
      browserCollect: (url) async => payload(observer: [
        obs('https://cdn.test/exact.js', tx: 11),
        {...obs('https://cdn.test/dir', tx: 22), 'it': 'other'},
        obs('https://cdn.test/cached.js?v=2', tx: 33),
        obs('https://files.test/chunk.js', tx: 44),
        {...obs('https://img.test/img/123/0.75/slug.jpg', tx: 55), 'it': 'img'},
        {...obs('https://other.test/p.jpg?width=264', tx: 66), 'it': 'img'},
      ]),
      nativeCookies: (u) async => [],
      browserPlatform: BrowserPlatform.macos,
      browserPoll: NetworkQuietPolicy.off,
      spaSettleDelay: Duration.zero,
      sizeLookup: (url) async => null,
    );
    service.setAppSettings(AppSettings()..useBrowserByDefault = true);

    await service.loadUrl('https://a.test/');
    fetcher.pending.last.complete(okSnapshot('https://a.test/', '<html>S</html>'));
    await pumpEventQueue();
    await service.syncWebViewState('https://a.test/');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final js = {
      for (final l in service.pageMetadata!['jsLinks'] as List)
        (l is Map ? l['src'] : l) as String: l
    };
    Map<String, dynamic> sizeOf(String src) =>
        (js[src] as Map)['size'] as Map<String, dynamic>;

    expect(sizeOf('https://cdn.test/exact.js')['transfer'], 11);
    expect(sizeOf('https://cdn.test/dir/')['transfer'], 22);
    expect(sizeOf('https://cdn.test/cached.js?v=1')['transfer'], 33);
    expect(sizeOf('https://a.test/deep/chunk.js')['transfer'], 44);

    final images = {
      for (final i in service.pageMetadata!['media']['images'] as List)
        (i as Map)['src'] as String: i
    };
    expect(
        (images['https://img.test/img/123/0.50/slug.jpg?w=100'] as Map)['size']
            ['transfer'],
        55);
    expect(
        (images['https://other.test/thumb.jpg?width=112'] as Map)['size'],
        isNull);
  });
}
