# Permissions and Storage Insight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Permissions tab that shows what a page is allowed to do, what it hands to third-party frames, what it asked for, and what it stored on the device (F2).

**Architecture:** Four sources, one derived model. *Declared*: the `Permissions-Policy` / `Feature-Policy` response headers (server core). *Delegated*: `allow` and `sandbox` of every iframe (collector). *Requested*: the WebView's native permission callbacks, which the app denies and records. *Stored*: quota, IndexedDB, Cache Storage and service workers, read by the collector without touching the page's own objects. JavaScript-level prompts that have no native callback (notifications, clipboard) are covered by plan 04's instrumented fresh load, not here.

**Tech Stack:** Flutter, `flutter_inappwebview` (`onPermissionRequest`, `onGeolocationPermissionsShowPrompt`), the collector JavaScript, `provider`.

**Spec:** `docs/audits/2026-11-15-explorer-audit.md` (F2).

**Depends on:** plan 01 Tasks 1 (Node harness), 4 (collector world) and 6 (`sameSite`).

## Global Constraints

- Everything in plan 01's Global Constraints applies.
- The app never grants a permission. Every native request is denied and recorded.
- The collector reads; it wraps or replaces nothing in the page (that is plan 04, fresh load only).
- Promise-based browser APIs cannot be awaited inside `__vsv_collect` (it returns synchronously). They are started once and their results are picked up by a later collect; until then the section is `Pending`.
- A browser that lacks an API gives `Unavailable(notReportedByPlatform)` for that field, never an empty list.

## Review Focus

1. A malformed `Permissions-Policy` header (`camera=(self`, `geolocation`, stray commas): parsed features are kept, the broken member is listed under `invalid`, nothing throws (Task 1).
2. A page with hundreds of iframes: the collector sends at most 200 and says how many there were (Task 2).
3. `indexedDB.databases` missing (older WebKit, Firefox-based views) or `navigator.storage` undefined on an insecure origin: that field is unavailable with the reason, the others still arrive (Task 2).
4. A permission request that arrives after the user navigated on: it is recorded for the page that asked, or dropped; never attached to the new page (Task 3).
5. A local file or a non-HTML document: the tab says there is nothing to check instead of showing empty sections (Task 4).

---

### Task 1: Parse Permissions-Policy, Feature-Policy and iframe `allow`

**Files:**
- Create: `lib/services/derive/permissions_policy.dart`
- Test: `test/derive/permissions_policy_test.dart`

**Interfaces:**
- Produces:

```dart
class Allowlist {
  final bool all;            // *
  final bool self;           // self / 'self'
  final bool src;            // 'src' (iframe allow only)
  final List<String> origins;
  bool get none => !all && !self && !src && origins.isEmpty;
  const Allowlist({this.all = false, this.self = false, this.src = false,
      this.origins = const []});
}

class ParsedPolicy {
  final Map<String, Allowlist> features;   // feature name → allowlist, header order
  final List<String> invalid;              // members that could not be parsed
  const ParsedPolicy(this.features, this.invalid);
}

/// `Permissions-Policy: geolocation=(), camera=(self "https://a.test"), fullscreen=*`
ParsedPolicy parsePermissionsPolicy(String header);

/// `Feature-Policy` header and iframe `allow` attribute:
/// `geolocation 'none'; camera 'self' https://a.test; fullscreen *`.
/// A feature without a value means 'src' for [iframeAllow], 'self' otherwise.
ParsedPolicy parseFeaturePolicy(String value, {bool iframeAllow = false});

/// Features that reach the device or the user: shown first, flagged when
/// delegated to a third party.
const Set<String> powerfulFeatures = {
  'camera', 'microphone', 'geolocation', 'display-capture', 'payment',
  'usb', 'serial', 'hid', 'bluetooth', 'midi', 'clipboard-read',
  'publickey-credentials-get', 'screen-wake-lock', 'idle-detection',
  'accelerometer', 'gyroscope', 'magnetometer', 'browsing-topics',
  'attribution-reporting', 'local-fonts',
};
```

- [ ] **Step 1: Write the failing tests**

```dart
test('permissions-policy', () {
  final p = parsePermissionsPolicy(
      'geolocation=(), camera=(self "https://a.test"), fullscreen=*, microphone=self');
  expect(p.features.keys, ['geolocation', 'camera', 'fullscreen', 'microphone']);
  expect(p.features['geolocation']!.none, isTrue);
  expect(p.features['camera']!.self, isTrue);
  expect(p.features['camera']!.origins, ['https://a.test']);
  expect(p.features['fullscreen']!.all, isTrue);
  expect(p.features['microphone']!.self, isTrue);
  expect(p.invalid, isEmpty);
});
test('a broken member does not lose the others', () {
  final p = parsePermissionsPolicy('camera=(self, geolocation=(), ,x');
  expect(p.features.keys, contains('geolocation'));
  expect(p.invalid, isNotEmpty);
});
test('repeated header values joined by a comma parse as one', () {
  expect(parsePermissionsPolicy('camera=(), microphone=()').features, hasLength(2));
});
test('iframe allow', () {
  final p = parseFeaturePolicy("camera; microphone 'none'; geolocation https://m.test *",
      iframeAllow: true);
  expect(p.features['camera']!.src, isTrue);
  expect(p.features['microphone']!.none, isTrue);
  expect(p.features['geolocation']!.all, isTrue);
  expect(p.features['geolocation']!.origins, ['https://m.test']);
});
test('empty input', () {
  expect(parsePermissionsPolicy('').features, isEmpty);
  expect(parseFeaturePolicy('  ').features, isEmpty);
});
```

- [ ] **Step 2: Run, see them fail, implement, run, commit**

Run: `flutter test test/derive/permissions_policy_test.dart`
The `Permissions-Policy` value is a structured-field dictionary: split members on commas that are outside parentheses and quotes; a member is `name=item` or `name=(inner list)`; tokens `*` and `self`; strings in double quotes are origins. Parameters (`;report-to=…`) are ignored.
```bash
git commit -am "Parse Permissions-Policy, Feature-Policy and iframe allow"
```

---

### Task 2: Collect iframe delegations and site storage

**Files:**
- Modify: `lib/services/collectors/vsv_collect_js.dart` (`vsvCollectJs`: two new sections)
- Modify: `lib/models/inspection/browser_snapshot.dart`
- Modify: `lib/services/collectors/browser_payload.dart`
- Modify: `lib/services/inspection_store.dart` (`_merge`: carry the new sections, a Present is never replaced by a non-Present)
- Test: `test/collectors/vsv_collect_js_test.dart`, `test/collectors/browser_payload_test.dart`, `test/services/inspection_store_test.dart`

**Interfaces:**
- Produces (payload):
  - `frames: {ok, total, items: [{src, allow, sandbox}]}`: at most 200 items; `sandbox` is null when the attribute is absent, `''` when present and empty.
  - `siteStorage`: `{ok: true, pending: true}` until the promises settle, then `{ok: true, usage, quota, idb: {ok, names} | {ok: false, error}, caches: {...same}, sw: {ok, items: [{scope, script}]} | {ok: false, error}}`. `usage`/`quota` are numbers or null.
- Produces (model):

```dart
class FrameInfo {
  final String src;          // absolute URL, '' for srcdoc/about:blank frames
  final String allow;        // raw attribute, '' when absent
  final String? sandbox;     // null = no sandbox attribute
  const FrameInfo({required this.src, this.allow = '', this.sandbox});
}

class ServiceWorkerInfo { final String scope; final String script; const ... }

class SiteStorage {
  final Observed<int> usageBytes;
  final Observed<int> quotaBytes;
  final Observed<List<String>> indexedDbNames;
  final Observed<List<String>> cacheNames;
  final Observed<List<ServiceWorkerInfo>> serviceWorkers;
  const SiteStorage({required ...});
}
```

  `BrowserSnapshot` gets `Observed<List<FrameInfo>> frames`, `int frameCount` (the page's total) and `Observed<SiteStorage> siteStorage`: optional constructor parameters that default to `Unavailable(UnavailableReason.notReportedByPlatform, 'not collected')`, carried through `copyWith`, `unavailable` and `failed`. All three classes get value `==`/`hashCode` (lists compared element-wise) so store merges stay identity-stable.

- [ ] **Step 1: Write the failing tests**

```dart
test('iframe attributes are collected, capped at 200', () async {
  final out = await runCollector(before: "var fr = []; for (var i = 0; i < 250; i++)"
      " fr.push({src: 'https://f.test/' + i, getAttribute: function(n) {"
      " return n === 'allow' ? 'camera' : null; }});"
      "document.getElementsByTagName = function(t) { return t === 'iframe' ? fr : []; };");
  if (out == null) return markTestSkipped('node not installed');
  expect(out['frames']['total'], 250);
  expect(out['frames']['items'], hasLength(200));
  expect(out['frames']['items'][0],
      {'src': 'https://f.test/0', 'allow': 'camera', 'sandbox': null});
});
test('site storage is pending until the promises settle', () async {
  // A promise that never settles; the other three APIs are absent.
  final out = await runCollector(before: "var navigator = {storage: {estimate:"
      " function() { return {then: function() { return {catch: function() {}}; }}; }}};");
  if (out == null) return markTestSkipped('node not installed');
  expect(out['siteStorage'], {'ok': true, 'pending': true});
});
test('a missing API is an error for that field only', () async {
  // before: window.__vsv_site = {done: true, usage: 10, quota: 100,
  //   idb: {ok: false, error: 'indexedDB.databases is not supported'},
  //   caches: {ok: true, names: ['v1']}, sw: {ok: true, items: []}};
  // expect out['siteStorage']['idb']['ok'] == false, ['caches']['names'] == ['v1']
});
// browser_payload_test.dart
test('site storage sections map to Observed', () {
  // pending → snap.siteStorage is Pending
  // settled with idb error → indexedDbNames is Unavailable(notReportedByPlatform, <error>),
  //   cacheNames Present(['v1']), usageBytes Present(10)
  // usage null → usageBytes Unavailable
});
test('frames resolve against the page URL', () {
  // items [{'src': '/embed', 'allow': 'camera; microphone', 'sandbox': ''}] on https://a.test/x
  // expect frames.single.src == 'https://a.test/embed', sandbox == ''
});
// inspection_store_test.dart
test('a later poll without site storage keeps the earlier result', () { /* Present stays */ });
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/collectors/ test/services/inspection_store_test.dart`

- [ ] **Step 3: Implement the collector sections**

`out.frames` is an ordinary `section(...)`. For site storage, on the first collect start the four lookups once (guard `window.__vsv_siteStarted`) and write into `window.__vsv_site`; each lookup has its own `try` and its own `.catch`, and a missing API is recorded as `{ok: false, error: '<api> is not supported'}`. `done` is set when all four have settled. Each collect reports `window.__vsv_site` when `done`, else `{ok: true, pending: true}`. APIs: `navigator.storage.estimate()`, `indexedDB.databases()`, `caches.keys()`, `navigator.serviceWorker.getRegistrations()` (script URL from `active || waiting || installing`).

- [ ] **Step 4: Implement the model, the parser and the merge; run the suite; commit**

Run: `flutter analyze --no-pub && flutter test`
```bash
git commit -am "Collect iframe permissions and site storage (quota, IndexedDB, caches, service workers)"
```

---

### Task 3: Record (and deny) native permission requests

**Files:**
- Create: `lib/models/inspection/permission_request.dart`
- Modify: `lib/models/inspection/page_inspection.dart`, `lib/services/inspection_store.dart`
- Modify: `lib/services/html_service.dart` (one method next to `onBrowserMainFrameHttpError`)
- Modify: `lib/widgets/browser_view.dart` (two callbacks)
- Test: `test/services/inspection_store_test.dart`, `test/services/html_service_browser_sync_test.dart`

**Interfaces:**
- Produces:

```dart
class PermissionRequestEvent {
  final String origin;            // who asked, e.g. https://maps.test
  final List<String> resources;   // 'camera', 'microphone', 'geolocation', ...
  final Duration sinceLoadStart;
  const PermissionRequestEvent({required this.origin, required this.resources,
      required this.sinceLoadStart});
}
```

- `PageInspection.permissionRequests` (`List<PermissionRequestEvent>`, default `const []`, in `copyWith` and `empty`).
- `InspectionStore.addPermissionRequest(int gen, PermissionRequestEvent e)`: appended for the current generation only; at most 50 per page.
- `HtmlService.onBrowserPermissionRequest(String origin, List<String> resources)`: stamps the time since the last `onBrowserLoadStart` and the current generation.
- `browser_view.dart`: `onPermissionRequest` returns `PermissionResponse(resources: request.resources, action: PermissionResponseAction.DENY)` after recording (resource names lower-cased: map the plugin's `PermissionResourceType` values to `camera`, `microphone`, `camera+microphone` → both, others by their name). `onGeolocationPermissionsShowPrompt` returns `GeolocationPermissionShowPromptResponse(origin: origin, allow: false, retain: false)` after recording `['geolocation']`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a permission request is kept for its own page only', () {
  final store = InspectionStore();
  final gen = store.beginUrl(Uri.parse('https://a.test/'));
  store.addPermissionRequest(gen, ev('https://a.test', ['camera']));
  expect(store.current.permissionRequests.single.resources, ['camera']);
  final next = store.beginUrl(Uri.parse('https://b.test/'));
  store.addPermissionRequest(gen, ev('https://a.test', ['microphone'])); // late
  expect(store.current.permissionRequests, isEmpty);
  expect(next, isNot(gen));
});
test('at most 50 requests are kept', () { /* 60 added → 50 */ });
```

- [ ] **Step 2: Run, see them fail, implement, run the suite**

- [ ] **Step 3: Real check (macOS)**

Run the app, open `https://webcamtests.com` (or any page with a "test my camera" button), press its button.
Expected: no system camera prompt appears; after Task 5 the Permissions tab lists the request.

- [ ] **Step 4: Commit**

```bash
git commit -am "Deny and record camera, microphone and location requests"
```

---

### Task 4: `derivePermissions`

**Files:**
- Create: `lib/services/derive/permissions_view.dart`
- Test: `test/derive/permissions_view_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3, `sameSite`, `registrableDomain`.
- Produces:

```dart
class DeclaredFeature { final String feature; final String allowed; final bool powerful; }
// allowed: 'nobody' | 'this site' | 'everyone' | 'this site, https://a.test'

class Delegation {
  final String frameHost;        // '' for srcdoc frames
  final bool thirdParty;
  final List<String> features;   // powerful ones first
  final bool sandboxed;
}

class PermissionsModel {
  /// Present: the header was sent (possibly with no features). Unavailable
  /// (notReportedByServer): no Permissions-Policy or Feature-Policy header.
  final Observed<List<DeclaredFeature>> declared;
  final List<String> invalidDeclarations;
  final bool legacyHeaderOnly;                 // only Feature-Policy was sent
  final Observed<List<Delegation>> delegations; // only frames with an allow attribute
  final int frameCount;
  final List<PermissionRequestEvent> requests;
  final Observed<SiteStorage> stored;
  final List<String> notes;                    // plain sentences for the top of the tab
}

Observed<PermissionsModel> derivePermissions(PageInspection p);
```

- `derivePermissions` is `Unavailable(notApplicable, 'only for web pages')` for a `FileTarget` or `NoTarget`, `Pending` while neither the server nor the browser has answered.
- Notes, in this order, each only when true:
  - `No Permissions-Policy header: embedded frames keep the browser's defaults.`
  - `N third-party frame(s) may use: camera, microphone` (union of powerful features delegated to third-party frames).
  - `The page asked for camera N s after it started loading.` (one per request; `without being asked` is not claimed, the app cannot see user gestures.)
  - `A service worker is installed: the site can run code in the background.`

- [ ] **Step 1: Write the failing tests**

```dart
test('declared features, powerful ones first', () {
  final m = present(derivePermissions(page(headers: {
    'permissions-policy': ['fullscreen=*, camera=(), geolocation=(self)']})));
  final d = (m.declared as Present<List<DeclaredFeature>>).value;
  expect(d.map((f) => '${f.feature}: ${f.allowed}'),
      ['camera: nobody', 'geolocation: this site', 'fullscreen: everyone']);
});
test('no header is unavailable, not an empty list', () {
  final m = present(derivePermissions(page(headers: {})));
  expect(m.declared, isA<Unavailable<List<DeclaredFeature>>>());
  expect(m.notes.first, startsWith('No Permissions-Policy header'));
});
test('a third-party frame with camera access is flagged', () {
  // page https://a.test/, frames: [FrameInfo(src: 'https://meet.other.test/x', allow: 'camera; microphone'),
  //                               FrameInfo(src: 'https://static.a.test/y', allow: 'fullscreen')]
  // expect delegations[0].thirdParty == true, features == ['camera', 'microphone']
  // expect delegations[1].thirdParty == false
  // expect notes to contain '1 third-party frame(s) may use: camera, microphone'
});
test('local files have no permissions to check', () {
  expect(derivePermissions(localFilePage), isA<Unavailable<PermissionsModel>>());
});
```

`page(...)` and `present(...)` are small helpers in the test built on `test/fixtures/inspection/builders.dart`.

- [ ] **Step 2: Run, see them fail, implement, run, commit**

```bash
git commit -am "Derive the permissions view: declared, delegated, requested, stored"
```

---

### Task 5: Permissions tab and export

**Files:**
- Modify: `lib/models/app_tab.dart` (new value after `security`): `permissions(TabGroup.trust, 'Permissions', Icons.admin_panel_settings_outlined, 'permissions')`, visible under the same condition as `security`
- Create: `lib/widgets/permissions_view.dart`
- Modify: `lib/screens/home_screen.dart` (page for the tab), `lib/services/html_service.dart` (getter `permissionsView`, cached on the identity of `store.current` like `generalView`)
- Modify: `lib/services/inspection_export_service.dart` (`analysis/permissions.json`), `lib/services/inspection_export_data.dart` (`permissions(Observed<PermissionsModel>)`)
- Modify: `README.md` feature list and `lib/screens/about_screen.dart` Key Features (one line each)
- Test: `test/widgets/permissions_data_test.dart`, `test/services/inspection_export_data_test.dart`, `test/tab_functionality_test.dart` (tab count)

**Interfaces:**
- Consumes: `derivePermissions` (Task 4), `SectionBox`, `ObservedValue` widgets, `AnalysisDisclaimer`.

Layout: the notes as a list at the top; then four `SectionBox`es: `Allowed by the site` (feature → who), `Handed to embedded frames` (frame host, third-party badge, features, `sandboxed`), `Asked while loading` (resource, origin, seconds; a line `Denied by this app` under the heading), `Stored on this device` (used / quota, IndexedDB names, cache names, service worker scopes, plus the existing local/session storage counts). A section whose data is not Present shows why with `ObservedValue`/`unknownText`, never an empty box.

Export shape: `observedJson` of the model with `declared`, `delegations`, `requests` (`origin`, `resources`, `sinceLoadStartMs`), `stored` (bytes and names; never values).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the tab shows the four sections with their data', (tester) async {
  await pumpPermissions(tester, pageWithPermissions);
  expect(find.text('Allowed by the site'), findsOneWidget);
  expect(find.text('camera'), findsWidgets);
  expect(find.textContaining('third-party'), findsOneWidget);
  expect(find.text('Denied by this app'), findsOneWidget);
});
testWidgets('no header: the reason is shown, not an empty box', (tester) async {
  await pumpPermissions(tester, pageWithoutPolicy);
  expect(find.textContaining('Not reported by the server'), findsOneWidget);
});
test('the export has no storage values', () {
  // InspectionExportData.permissions(...) → jsonEncode contains IndexedDB names,
  // and no key named 'value' or 'v'
});
```

`pumpPermissions` is a local helper: a store holding the fixture, `makeService` and `pumpWithProviders` from `test/fixtures/inspection/pump.dart` around `PermissionsView`, the way `test/widgets/probe_security_data_test.dart` pumps its view.

- [ ] **Step 2: Run, see them fail, implement, run the suite**

Run: `flutter analyze --no-pub && flutter test`
Expected: PASS including the architecture test (the widget only reads `permissionsView`).

- [ ] **Step 3: Real check and commit**

Run the app on macOS, open a news site with video embeds.
Expected: the tab lists the header's features (or says there is none), the embed frames with their `allow` features, and a storage section with a used/quota figure.

```bash
git add -A && git commit -m "Add Permissions tab: declared, delegated, requested, stored"
```

---

## Final gate

- [ ] `flutter analyze --no-pub && flutter test`: clean, all pass.
- [ ] Plan 02's summary gains two rules (add them to `inspection_summary.dart` with tests when plan 02 is merged; skip otherwise): `permission-request` (medium): `The page asked for <resources> while loading`; `third-party-device-access` (medium): `N third-party frame(s) may use: <features>`.
- [ ] `CHANGELOG.md` entry.
