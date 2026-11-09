import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

DecodedText _text(String s) => DecodedText(
    text: s,
    charset: 'utf-8',
    charsetSource: CharsetSource.fallback,
    byteLength: s.length);

ServerSnapshot _server(String url, {String body = '<p>s</p>'}) =>
    ServerSnapshot(
      requestedUrl: Uri.parse(url),
      userAgent: 'ua',
      hops: const [],
      finalUrl: Present(Uri.parse(url), source: DataSource.server),
      body: Present(
          ServerBody(
              decoded: _text(body),
              transferLength: body.length,
              truncated: false,
              contentLength:
                  const Unavailable(UnavailableReason.notReportedByServer)),
          source: DataSource.server),
      timingMs: const Present(5, source: DataSource.server),
      certificate: const Unavailable(UnavailableReason.notApplicable),
    );

ResourceEntry _res(String url, {int? transfer}) => ResourceEntry(
      url: url,
      type: 'img',
      source: ResourceSource.observer,
      startTime: const Present(1.0, source: DataSource.browser),
      duration: const Present(2.0, source: DataSource.browser),
      transfer: transfer == null
          ? const Unavailable(UnavailableReason.notReportedByPlatform)
          : Present(transfer, source: DataSource.browser),
      decoded: const Unavailable(UnavailableReason.notReportedByPlatform),
    );

BrowserSnapshot _browser(String url,
        {String? dom,
        List<ResourceEntry>? resources,
        bool truncated = false,
        int dropped = 0}) =>
    BrowserSnapshot(
      url: Uri.parse(url),
      platform: BrowserPlatform.macos,
      contentType: const Unavailable(UnavailableReason.notExposedToPage),
      renderedDom: dom == null
          ? const Unavailable(UnavailableReason.notExposedToPage)
          : Present(RenderedDom(text: dom), source: DataSource.browser),
      resources: resources == null
          ? const Unavailable(UnavailableReason.notExposedToPage)
          : Present(resources, source: DataSource.browser),
      cookies: const Unavailable(UnavailableReason.notExposedToPage),
      storage: const Unavailable(UnavailableReason.notExposedToPage),
      navigation: const Unavailable(UnavailableReason.notExposedToPage),
      snapshotTimeMs: const Present(10.0, source: DataSource.browser),
      resourcesTruncated: truncated,
      resourcesDropped: dropped,
    );

FileSnapshot _file() => FileSnapshot(
      name: 'a.html',
      path: '/tmp/a.html',
      origin: FileOrigin.picker,
      bytes: const [60, 112, 62],
      text: _text('<p>'),
      lastModified: const Unavailable(UnavailableReason.notApplicable),
    );

void main() {
  late InspectionStore store;
  late int notifies;
  setUp(() {
    store = InspectionStore();
    notifies = 0;
    store.addListener(() => notifies++);
  });

  test('initial state is empty and unavailable', () {
    final c = store.current;
    expect(c.generation, 0);
    expect(c.target, isA<NoTarget>());
    expect(c.server, isA<Unavailable<ServerSnapshot>>());
    expect(c.browser, isA<Unavailable<BrowserSnapshot>>());
    expect(c.file, isA<Unavailable<FileSnapshot>>());
    expect(c.primaryDocument, isNull);
  });

  test('beginUrl: new generation, server/browser pending, file n/a', () {
    final g1 = store.beginUrl(Uri.parse('https://a.test/'));
    final g2 = store.beginUrl(Uri.parse('https://b.test/'));
    expect(g2, greaterThan(g1));
    expect(store.current.generation, g2);
    expect(store.current.server, isA<Pending<ServerSnapshot>>());
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
    expect(store.current.file, isA<Unavailable<FileSnapshot>>());
    expect(notifies, 2);
  });

  test('stale server result after a new begin is ignored, B stays pending',
      () async {
    final a = Completer<Observed<ServerSnapshot>>();
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    final fut = a.future.then((r) => store.applyServer(genA, r));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    a.complete(Present(_server('https://a.test/'), source: DataSource.server));
    await fut;
    expect(store.current.server, isA<Pending<ServerSnapshot>>());
    expect(notifies, 0);
  });

  test('stale browser payload after a new begin is ignored', () {
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    store.applyBrowser(genA, _browser('https://a.test/', dom: '<p>a</p>'));
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
    expect(notifies, 0);
  });

  test('stale robots and failure are ignored', () {
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    store.applyRobots(genA, const Pending());
    store.applyBrowserFailure(genA, const Failed('x'));
    expect(notifies, 0);
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
  });

  test('URL fully loaded then beginFile clears server/browser', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p/>', resources: [_res('https://a.test/x.png')]));
    store.beginFile(_file());
    final c = store.current;
    expect(c.target, isA<FileTarget>());
    expect(c.server, isA<Unavailable<ServerSnapshot>>());
    expect((c.server as Unavailable).reason, UnavailableReason.notApplicable);
    expect(c.browser, isA<Unavailable<BrowserSnapshot>>());
    expect((c.browser as Unavailable).reason, UnavailableReason.notApplicable);
    expect(c.file, isA<Present<FileSnapshot>>());
    expect(c.primaryDocument, DataSource.file);
  });

  test('local file: no fake probe; applyBrowser/applyServer ignored', () {
    final g = store.beginFile(_file());
    notifies = 0;
    store.applyBrowser(g, _browser('file:///tmp/a.html', dom: '<p/>'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.server, isA<Unavailable<ServerSnapshot>>());
    expect(store.current.browser, isA<Unavailable<BrowserSnapshot>>());
    expect(notifies, 0);
  });

  test('one applyBrowser = exactly one notify', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    notifies = 0;
    store.applyBrowser(g, _browser('https://a.test/', dom: '<p/>'));
    expect(notifies, 1);
    expect(store.current.browser, isA<Present<BrowserSnapshot>>());
  });

  test('server Failed stays visible', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(g, const Failed('timeout'));
    final s = store.current.server;
    expect(s, isA<Failed<ServerSnapshot>>());
    expect((s as Failed).error, 'timeout');
  });

  test('second applyBrowser merges resources, takes fresher DOM', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>1</p>',
            resources: [_res('https://a.test/1.png', transfer: 10)]));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>2</p>', resources: [_res('https://a.test/2.png')]));
    final b = (store.current.browser as Present<BrowserSnapshot>).value;
    expect(((b.renderedDom as Present<RenderedDom>).value).text, '<p>2</p>');
    final urls =
        (b.resources as Present<List<ResourceEntry>>).value.map((e) => e.url);
    expect(urls, containsAll(['https://a.test/1.png', 'https://a.test/2.png']));
  });

  test('later non-Present sections never overwrite Present ones', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>1</p>', resources: [_res('https://a.test/1.png')]));
    store.applyBrowser(g, _browser('https://a.test/'));
    store.applyBrowserFailure(g, const Failed('late'));
    final b = store.current.browser;
    expect(b, isA<Present<BrowserSnapshot>>());
    final v = (b as Present<BrowserSnapshot>).value;
    expect(v.renderedDom, isA<Present<RenderedDom>>());
    expect(v.resources, isA<Present<List<ResourceEntry>>>());
  });

  test('applyBrowserFailure stores Failed when nothing Present', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowserFailure(g, const Failed('boom'));
    expect(store.current.browser, isA<Failed<BrowserSnapshot>>());
  });

  RobotsInfo robotsInfo() => const RobotsInfo(
        robotsStatus: Present(200, source: DataSource.server),
        robotsText: Present('User-agent: *', source: DataSource.server),
        disallowCount: Present(0, source: DataSource.server),
        allowCount: Present(0, source: DataSource.server),
        sitemaps: Present(<String>[], source: DataSource.server),
        sitemapStatus: Unavailable(UnavailableReason.notApplicable),
      );

  test('robots before server are kept, and survive the server arriving', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyRobots(g, Present(robotsInfo(), source: DataSource.server));
    expect(store.current.robots, isA<Present<RobotsInfo>>());
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.robots, isA<Present<RobotsInfo>>());
  });

  test('robots after server are kept; begin resets them', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    store.applyRobots(g, Present(robotsInfo(), source: DataSource.server));
    expect(store.current.robots, isA<Present<RobotsInfo>>());
    store.beginUrl(Uri.parse('https://b.test/'));
    expect(store.current.robots, isA<Pending<RobotsInfo>>());
  });

  test('stale robots ignored', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    store.applyRobots(g, Present(robotsInfo(), source: DataSource.server));
    expect(store.current.robots, isA<Pending<RobotsInfo>>());
    expect(notifies, 0);
  });

  test('Failed/Unavailable server never replaces a Present server', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    notifies = 0;
    store.applyServer(g, const Failed('late'));
    store.applyServer(g, const Unavailable(UnavailableReason.blockedBySite));
    expect(store.current.server, isA<Present<ServerSnapshot>>());
    expect(notifies, 0);
    store.applyServer(
        g,
        Present(_server('https://a.test/', body: 'new'),
            source: DataSource.server));
    expect(notifies, 1);
  });

  test('truncation flag is OR-ed, dropped count is the max', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p/>',
            resources: [_res('https://a.test/1.png')],
            truncated: true,
            dropped: 7));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            resources: [_res('https://a.test/2.png')], dropped: 3));
    final b = (store.current.browser as Present<BrowserSnapshot>).value;
    expect(b.resourcesTruncated, isTrue);
    expect(b.resourcesDropped, 7);
  });

  test('all-unavailable browser payload over Present: no change, no notify',
      () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(g, _browser('https://a.test/', dom: '<p/>'));
    final before = store.current;
    notifies = 0;
    store.applyBrowser(
        g,
        BrowserSnapshot.unavailable(Uri.parse('https://a.test/'),
            BrowserPlatform.macos, UnavailableReason.notExposedToPage, 'x'));
    expect(notifies, 0);
    expect(identical(store.current, before), isTrue);
  });

  test('begin* resets primaryDocumentPreference', () {
    store.beginUrl(Uri.parse('https://a.test/'));
    store.setPrimaryDocument(DataSource.server);
    store.beginUrl(Uri.parse('https://b.test/'));
    expect(store.current.primaryDocumentPreference, isNull);
    store.setPrimaryDocument(DataSource.file);
    store.beginFile(_file());
    expect(store.current.primaryDocumentPreference, isNull);
  });

  test('primaryDocument rule and preference', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    expect(store.current.primaryDocument, isNull);
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.primaryDocument, DataSource.server);
    store.applyBrowser(g, _browser('https://a.test/', dom: '<p/>'));
    expect(store.current.primaryDocument, DataSource.browser);
    store.setPrimaryDocument(DataSource.server);
    expect(store.current.primaryDocument, DataSource.server);
    store.setPrimaryDocument(DataSource.file); // not present: falls back
    expect(store.current.primaryDocument, DataSource.browser);
    notifies = 0;
    store.setPrimaryDocument(DataSource.file); // no-op
    expect(notifies, 0);
    store.setPrimaryDocument(null);
    expect(notifies, 1);
  });

  test('clear starts a new generation with nothing loaded', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    notifies = 0;
    store.clear();
    expect(store.current.generation, g + 1);
    expect(store.current.target, isA<NoTarget>());
    expect(store.current.server, isA<Unavailable<ServerSnapshot>>());
    expect(notifies, 1);
    // A late result of the cleared navigation is dropped.
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.server, isA<Unavailable<ServerSnapshot>>());
  });

  group('applyEstimates', () {
    Present<int> est(int v) =>
        Present(v, source: DataSource.server, provenance: Provenance.estimated);

    test('one apply = one notify; results are merged per URL', () {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      notifies = 0;
      store.applyEstimates(g, {'https://a.test/a.js': est(10)});
      expect(notifies, 1);
      store.applyEstimates(g, {'https://a.test/b.js': est(20)});
      expect(notifies, 2);
      expect(store.current.resourceEstimates.keys,
          ['https://a.test/a.js', 'https://a.test/b.js']);
    });

    test('a stale generation is dropped without a notify', () {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      store.beginUrl(Uri.parse('https://b.test/'));
      notifies = 0;
      store.applyEstimates(g, {'https://a.test/a.js': est(10)});
      expect(notifies, 0);
      expect(store.current.resourceEstimates, isEmpty);
    });

    test('a failure never replaces a Present estimate; empty is a no-op', () {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      store.applyEstimates(g, {'https://a.test/a.js': est(10)});
      notifies = 0;
      store.applyEstimates(g, {'https://a.test/a.js': const Failed('x')});
      store.applyEstimates(g, {});
      expect(notifies, 0);
      expect(store.current.resourceEstimates['https://a.test/a.js'],
          isA<Present<int>>());
    });

    test('a new navigation starts without estimates', () {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      store.applyEstimates(g, {'https://a.test/a.js': est(10)});
      store.beginUrl(Uri.parse('https://b.test/'));
      expect(store.current.resourceEstimates, isEmpty);
    });

    test('queued estimates coalesce into one notify per event-loop turn',
        () async {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      notifies = 0;
      for (var i = 0; i < 50; i++) {
        store.queueEstimate(g, 'https://a.test/$i.js', est(i));
      }
      // Nothing applied synchronously yet.
      expect(notifies, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notifies, 1);
      expect(store.current.resourceEstimates.length, 50);
    });

    test('queued estimates of a stale generation are dropped at flush',
        () async {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      store.queueEstimate(g, 'https://a.test/a.js', est(10));
      store.beginUrl(Uri.parse('https://b.test/')); // g is now stale
      notifies = 0;
      await Future<void>.delayed(Duration.zero);
      expect(notifies, 0);
      expect(store.current.resourceEstimates, isEmpty);
    });
  });

  group('applyDeclaredMedia', () {
    test('one apply = one notify; same list is a no-op; stale is dropped', () {
      final g = store.beginUrl(Uri.parse('https://a.test/'));
      notifies = 0;
      store.applyDeclaredMedia(g, ['https://img.a.test/a.gif']);
      expect(notifies, 1);
      expect(store.current.declaredMedia, ['https://img.a.test/a.gif']);
      store.applyDeclaredMedia(g, ['https://img.a.test/a.gif']);
      expect(notifies, 1);
      store.applyDeclaredMedia(g, ['https://img.a.test/a.gif', 'https://img.a.test/b.gif']);
      expect(notifies, 2);
      expect(store.current.declaredMedia.length, 2);
      store.beginUrl(Uri.parse('https://b.test/'));
      notifies = 0;
      store.applyDeclaredMedia(g, ['https://img.a.test/c.gif']);
      expect(notifies, 0);
      expect(store.current.declaredMedia, isEmpty);
    });
  });
}
