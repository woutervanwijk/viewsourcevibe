import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/permission_request.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/permissions_view.dart';

import '../derive/fixtures.dart' show inspection, serverSnap, browserSnap, b;
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

PageInspection pageWith({
  Map<String, List<String>> headers = const {},
  List<FrameInfo> frames = const [],
  SiteStorage? storage,
  List<PermissionRequestEvent> requests = const [],
}) {
  final snap = browserSnap(url: 'https://a.test/');
  final full = BrowserSnapshot(
    url: snap.url,
    platform: snap.platform,
    contentType: snap.contentType,
    renderedDom: snap.renderedDom,
    resources: snap.resources,
    cookies: snap.cookies,
    storage: b(BrowserStorage(
      local: b(StorageArea(
          count: 3,
          bytes: b(120),
          topItems: const [StorageItem('secret-token-key', 987654)])),
      session: b(StorageArea(count: 0, bytes: b(0), topItems: const [])),
    )),
    navigation: snap.navigation,
    snapshotTimeMs: snap.snapshotTimeMs,
    frames: b(frames),
    frameCount: frames.length,
    siteStorage: storage == null ? kSiteStorageNotCollected : b(storage),
  );
  return inspection(
          server: serverSnap(url: 'https://a.test/', headers: headers),
          browser: full)
      .copyWith(permissionRequests: requests);
}

final pageWithPermissions = pageWith(
  headers: {
    'permissions-policy': ['camera=(), fullscreen=*']
  },
  frames: const [
    FrameInfo(
        src: 'https://video.other.net/embed',
        allow: 'camera; autoplay',
        sandbox: ''),
  ],
  storage: SiteStorage(
    usageBytes: b(2048),
    quotaBytes: b(10 * 1024 * 1024),
    indexedDbNames: b(['keyval-store']),
    cacheNames: b(['workbox-precache']),
    serviceWorkers: b([
      const ServiceWorkerInfo(scope: 'https://a.test/', script: '/sw.js'),
    ]),
  ),
  requests: const [
    PermissionRequestEvent(
        origin: 'https://maps.test',
        resources: ['geolocation'],
        sinceLoadStart: Duration(milliseconds: 1500)),
  ],
);

final pageWithoutPolicy = pageWith();

void main() {
  Future<void> pumpPermissions(WidgetTester tester, PageInspection p) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = seedStore(InspectionStore(), p);
    for (final r in p.permissionRequests) {
      store.addPermissionRequest(store.current.generation, r);
    }
    final service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PermissionsView());
    await tester.pump();
  }

  testWidgets('the tab shows the four sections with their data',
      (tester) async {
    await pumpPermissions(tester, pageWithPermissions);
    expect(find.text('Allowed by the site'), findsOneWidget);
    expect(find.text('Handed to embedded frames'), findsOneWidget);
    expect(find.text('Asked while loading'), findsOneWidget);
    expect(find.text('Stored on this device'), findsOneWidget);
    expect(find.text('camera'), findsWidgets);
    // the note, and the badge on the delegation row
    expect(find.textContaining('third-party frame(s) may use: camera'),
        findsOneWidget);
    expect(find.text('third-party'), findsOneWidget);
    expect(find.text('video.other.net'), findsOneWidget);
    expect(find.text('Denied by this app'), findsOneWidget);
    expect(find.textContaining('geolocation'), findsWidgets);
    expect(find.textContaining('keyval-store'), findsOneWidget);
    expect(find.textContaining('workbox-precache'), findsOneWidget);
    expect(find.textContaining('https://a.test/'), findsWidgets);
    expect(find.textContaining('2.0 KB of 10.0 MB'), findsOneWidget);
  });

  testWidgets('no header: the reason is shown, not an empty box',
      (tester) async {
    await pumpPermissions(tester, pageWithoutPolicy);
    expect(find.textContaining('Not reported by the server'), findsOneWidget);
    expect(find.text('No requests.'), findsOneWidget);
  });

  testWidgets('a local file says the tab is only for web pages',
      (tester) async {
    await pumpPermissions(tester, localFile());
    expect(find.textContaining('only for web pages'), findsOneWidget);
    expect(find.text('Allowed by the site'), findsNothing);
  });
}
