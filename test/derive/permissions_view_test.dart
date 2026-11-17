import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/permission_request.dart';
import 'package:view_source_vibe/services/derive/permissions_view.dart';

import '../fixtures/inspection/local_file.dart';
import 'fixtures.dart';

PageInspection page({
  Map<String, List<String>> headers = const {},
  List<FrameInfo>? frames,
  SiteStorage? storage,
  List<PermissionRequestEvent> requests = const [],
}) {
  final snap = browserSnap(url: 'https://a.test/');
  final withExtras = BrowserSnapshot(
    url: snap.url,
    platform: snap.platform,
    contentType: snap.contentType,
    renderedDom: snap.renderedDom,
    resources: snap.resources,
    cookies: snap.cookies,
    storage: snap.storage,
    navigation: snap.navigation,
    snapshotTimeMs: snap.snapshotTimeMs,
    frames: frames == null ? kFramesNotCollected : b(frames),
    frameCount: frames?.length ?? 0,
    siteStorage: storage == null ? kSiteStorageNotCollected : b(storage),
  );
  return inspection(
          server: serverSnap(url: 'https://a.test/', headers: headers),
          browser: withExtras)
      .copyWith(permissionRequests: requests);
}

PermissionsModel present(Observed<PermissionsModel> o) =>
    (o as Present<PermissionsModel>).value;

void main() {
  test('declared features, powerful ones first', () {
    final m = present(derivePermissions(page(headers: {
      'permissions-policy': ['fullscreen=*, camera=(), geolocation=(self)']
    })));
    final d = (m.declared as Present<List<DeclaredFeature>>).value;
    expect(d.map((f) => '${f.feature}: ${f.allowed}'),
        ['camera: nobody', 'geolocation: this site', 'fullscreen: everyone']);
    expect(m.legacyHeaderOnly, isFalse);
  });

  test('no header is unavailable, not an empty list', () {
    final m = present(derivePermissions(page(headers: {})));
    expect(m.declared, isA<Unavailable<List<DeclaredFeature>>>());
    expect(m.notes.first, startsWith('No Permissions-Policy header'));
  });

  test('origins are listed after this site', () {
    final m = present(derivePermissions(page(headers: {
      'permissions-policy': ['camera=(self "https://b.test")']
    })));
    final d = (m.declared as Present<List<DeclaredFeature>>).value;
    expect(d.single.allowed, 'this site, https://b.test');
  });

  test('Feature-Policy alone is legacy; Permissions-Policy wins when both', () {
    var m = present(derivePermissions(page(headers: {
      'feature-policy': ["camera 'none'"]
    })));
    expect(m.legacyHeaderOnly, isTrue);
    expect((m.declared as Present<List<DeclaredFeature>>).value.single.allowed,
        'nobody');
    m = present(derivePermissions(page(headers: {
      'feature-policy': ["camera 'none'"],
      'permissions-policy': ['camera=*']
    })));
    expect(m.legacyHeaderOnly, isFalse);
    expect((m.declared as Present<List<DeclaredFeature>>).value.single.allowed,
        'everyone');
  });

  test('a header with no features is present and empty; bad members listed',
      () {
    final m = present(derivePermissions(page(headers: {
      'permissions-policy': ['camera=(self']
    })));
    expect((m.declared as Present<List<DeclaredFeature>>).value, isEmpty);
    expect(m.invalidDeclarations, ['camera=(self']);
    expect(m.notes, isNot(contains(startsWith('No Permissions-Policy'))));
  });

  test('a third-party frame with camera access is flagged', () {
    final m = present(derivePermissions(page(frames: const [
      FrameInfo(src: 'https://meet.other.test/x', allow: 'camera; microphone'),
      FrameInfo(src: 'https://static.a.test/y', allow: 'fullscreen'),
      FrameInfo(src: 'https://nothing.other.test/'),
      FrameInfo(src: '', allow: 'geolocation', sandbox: ''),
    ])));
    final d = (m.delegations as Present<List<Delegation>>).value;
    expect(d.length, 3);
    expect(d[0].thirdParty, isTrue);
    expect(d[0].features, ['camera', 'microphone']);
    expect(d[0].frameHost, 'meet.other.test');
    expect(d[1].thirdParty, isFalse);
    expect(d[2].frameHost, '');
    expect(d[2].thirdParty, isFalse);
    expect(d[2].sandboxed, isTrue);
    expect(m.frameCount, 4);
    expect(m.notes,
        contains('1 third-party frame(s) may use: camera, microphone'));
  });

  test('requests become notes with one decimal below ten seconds', () {
    final m = present(derivePermissions(page(requests: const [
      PermissionRequestEvent(
          origin: 'https://a.test',
          resources: ['camera'],
          sinceLoadStart: Duration(milliseconds: 2340)),
      PermissionRequestEvent(
          origin: 'https://a.test',
          resources: ['geolocation'],
          sinceLoadStart: Duration(milliseconds: 12400)),
    ])));
    expect(m.requests.length, 2);
    expect(m.notes, [
      'No Permissions-Policy header: embedded frames keep the browser\'s defaults.',
      'The page asked for camera 2.3 s after it started loading.',
      'The page asked for geolocation 12 s after it started loading.',
    ]);
  });

  test('a service worker is noted', () {
    final m = present(derivePermissions(page(
        storage: const SiteStorage(
            usageBytes: Unavailable(UnavailableReason.notReportedByPlatform),
            quotaBytes: Unavailable(UnavailableReason.notReportedByPlatform),
            indexedDbNames:
                Unavailable(UnavailableReason.notReportedByPlatform),
            cacheNames: Unavailable(UnavailableReason.notReportedByPlatform),
            serviceWorkers: Present(
                [ServiceWorkerInfo(scope: 'https://a.test/', script: 'sw.js')],
                source: DataSource.browser)))));
    expect(m.notes.last,
        'A service worker is installed: the site can run code in the background.');
    expect(m.stored, isA<Present<SiteStorage>>());
  });

  test('states: browser pending, nothing answered', () {
    expect(derivePermissions(page().copyWith(browser: const Pending())),
        isA<Present<PermissionsModel>>());
    final m =
        present(derivePermissions(page().copyWith(browser: const Pending())));
    expect(m.delegations, isA<Pending<List<Delegation>>>());
    expect(
        derivePermissions(const PageInspection.empty()
            .copyWith(server: const Pending(), browser: const Pending())),
        isA<Unavailable<PermissionsModel>>());
    final both =
        page().copyWith(server: const Pending(), browser: const Pending());
    expect(derivePermissions(both), isA<Pending<PermissionsModel>>());
  });

  test('local files have no permissions to check', () {
    expect(
        derivePermissions(localFile()), isA<Unavailable<PermissionsModel>>());
    expect(derivePermissions(const PageInspection.empty()),
        isA<Unavailable<PermissionsModel>>());
  });
  test('allow="camera none" delegates nothing and raises no note', () {
    final m = present(derivePermissions(page(frames: const [
      FrameInfo(src: 'https://meet.other.test/x', allow: 'camera none'),
    ])));
    expect((m.delegations as Present<List<Delegation>>).value.single.features,
        isEmpty);
    expect(m.notes.where((n) => n.contains('third-party')), isEmpty);
  });

  test('9.96 s prints as 10 s', () {
    final m = present(derivePermissions(page(requests: const [
      PermissionRequestEvent(
          origin: 'https://a.test',
          resources: ['camera'],
          sinceLoadStart: Duration(milliseconds: 9960)),
    ])));
    expect(m.notes.last,
        'The page asked for camera 10 s after it started loading.');
  });

  test('unavailable detail is pinned', () {
    final u = derivePermissions(localFile()) as Unavailable<PermissionsModel>;
    expect(u.reason, UnavailableReason.notApplicable);
    expect(u.detail, 'only for web pages');
  });
}
