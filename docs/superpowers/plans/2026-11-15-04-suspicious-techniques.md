# Suspicious Techniques Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show which tracking techniques a page uses beyond loading known trackers: device fingerprinting, WebRTC probing, permission prompts on load, identifiers shared between parties, trackers hidden behind a first-party hostname, and third-party scripts without integrity checks (F3).

**Architecture:** Two kinds of evidence. *Observed calls*: fingerprinting can only be seen by wrapping browser APIs in the page's own JavaScript world, which a page can detect and which may change what it does. So the wrappers run **only in the separate, off-screen fresh load** (`HeadlessFreshLoadMeasurer`); the live browser stays untouched. *Derived from data the app already has*: identifier sharing (cookies × request URLs), CNAME cloaking (DNS), missing SRI (DOM). One pure `deriveTechniques` turns signals into findings; the Privacy tab shows them.

**Tech Stack:** Flutter, `flutter_inappwebview` headless WebView, collector JavaScript, DNS-over-HTTPS (the resolver code in `SovereigntyService`).

**Spec:** `docs/audits/2026-11-15-explorer-audit.md` (F3).

**Depends on:** plan 01 Tasks 1, 4, 6. Plan 02 (optional: summary rules and the batch `freshLoad` option). Plan 03 Task 3 (optional: prompts recorded here are listed next to the native requests).

## Global Constraints

- Everything in plan 01's Global Constraints applies.
- The instrumentation script is never added to the live browser (`browser_view.dart`).
- A finding is an indication. Titles say what was seen (`reads back a canvas it drew text on`), not what it proves (`fingerprints you`); the tab keeps the existing `AnalysisDisclaimer`.
- Cookie values are compared in memory only. No value, and no part of one, is shown, logged or exported.
- Thresholds are named constants in one file with the source they come from in a comment.
- Not measured is not clean: without a fresh load the call-based checks are `Unavailable` with the text `Run a fresh load to check`, never "none found".

## Review Focus

1. A page that redefines or freezes the wrapped APIs (`Object.freeze(HTMLCanvasElement.prototype)`, its own `toDataURL` wrapper): the instrumentation must not throw into the page and the report is still produced (Task 1 test `a frozen prototype does not break the page`).
2. Windows and Linux have no headless WebView: the section says it is unsupported there; the data-derived checks still show (Task 5 test).
3. A canvas used legitimately (charts, image editing: drawn, read back, but no text or a single colour): no canvas finding (Task 2 test `a chart is not a fingerprint`).
4. A cookie whose value is short or common (`1`, `true`, `en`, a 10-digit timestamp): never reported as a shared identifier (Task 3 test).
5. DNS lookup failure or timeout for one host: the other hosts are still checked; the failed one is listed as not checked (Task 4 test).

---

### Task 1: Instrumentation script (fresh load only)

**Files:**
- Create: `lib/services/collectors/vsv_techniques_js.dart`
- Modify: `test/support/collector_node.dart` (add `runJs`)
- Test: `test/collectors/vsv_techniques_js_test.dart`

**Interfaces:**
- Produces: `const String vsvTechniquesJs`: wraps APIs at document start and defines `window.__vsv_tech_report()`, which returns a JSON string:

```json
{"v": 1,
 "canvas": [{"w": 300, "h": 150, "chars": 34, "colors": 2, "reads": 1, "script": "https://…/fp.js"}],
 "fonts": {"measureCalls": 420, "distinctFonts": 96, "script": "…"},
 "webgl": {"debugInfo": true, "script": "…"},
 "audio": {"offline": 1, "oscillators": 1, "rendered": 1, "script": "…"},
 "rtc": {"connections": 1, "dataChannels": 1, "offers": 1, "getUserMedia": 0, "script": "…"},
 "enumerateDevices": 0, "battery": 0, "clipboardRead": 0,
 "prompts": [{"api": "notifications", "atMs": 812, "userActive": false, "script": "…"}]}
```

  `canvas` has one record per canvas element that was read (at most 20). `chars` = distinct characters passed to `fillText`/`strokeText` on it; `colors` = distinct `fillStyle` values set before those calls; `reads` = `toDataURL` + `toBlob` + `getImageData` calls (a `getImageData` smaller than 16×16 is not counted). `webgl.debugInfo` = `getExtension('WEBGL_debug_renderer_info')` or `getParameter(37445 | 37446)`. `prompts[].api` is one of `notifications`, `geolocation`, `camera-microphone`, `clipboard`, `midi`, `storage-access`; `userActive` is `navigator.userActivation.isActive` at the call, or null where that does not exist. `script` is the first URL in `new Error().stack` that is not the page URL (at most 300 characters), or `''`.
- Produces (test helper): `Future<String?> runJs(String source)`: runs `source` in Node and returns stdout; null without Node. `runCollector` is rewritten on top of it.

Rules for the script: ES5; every wrapper is `try { record } catch (e) {}` around the bookkeeping and then calls the original with the original `this` and arguments, returning its result unchanged; a missing API is skipped; an API that cannot be redefined (frozen, non-configurable) is skipped. Nothing is blocked or altered.

- [ ] **Step 1: Write the failing tests**

Each test defines the fake browser objects it needs in a `before` string, loads `vsvTechniquesJs`, plays the page's calls, and decodes `__vsv_tech_report()`.

```dart
test('text drawn in two colours and read back is recorded', () async {
  final r = await report('''
    var c = new HTMLCanvasElement(); c.width = 300; c.height = 150;
    var x = c.getContext('2d');
    x.fillStyle = '#f60'; x.fillText('Cwm fjordbank glyphs vext quiz', 2, 15);
    x.fillStyle = 'rgba(102,204,0,0.7)'; x.fillText('Cwm fjordbank glyphs vext quiz', 4, 17);
    c.toDataURL();''');
  if (r == null) return markTestSkipped('node not installed');
  expect(r['canvas'].single, containsPair('reads', 1));
  expect(r['canvas'].single['colors'], 2);
  expect(r['canvas'].single['chars'], greaterThanOrEqualTo(10));
});
test('the original result is returned unchanged', () async {
  // fake toDataURL returns 'data:,x'; expect the page-visible result to be 'data:,x'
});
test('webgl debug info and audio rendering are recorded', () async { /* debugInfo true; offline 1, oscillators 1, rendered 1 */ });
test('a notification prompt without a click is recorded', () async {
  // navigator.userActivation = {isActive: false}; Notification.requestPermission()
  // expect prompts.single api 'notifications', userActive false
});
test('a frozen prototype does not break the page', () async {
  // Object.freeze(HTMLCanvasElement.prototype) before the script loads;
  // the page then calls c.toDataURL(): no exception, report still parses
});
test('nothing called gives an empty report', () async {
  // expect canvas == [], fonts.measureCalls == 0, prompts == []
});
```

The fake classes (`HTMLCanvasElement` with `getContext`, `toDataURL`, `toBlob`; `CanvasRenderingContext2D` with `fillText`, `strokeText`, `measureText`, `getImageData`, a `fillStyle` and `font` property; `WebGLRenderingContext`; `OfflineAudioContext`; `RTCPeerConnection`; `Notification`; `navigator`) live in one Dart string constant in the test file.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/collectors/vsv_techniques_js_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement the script**

`fillStyle` and `font` are accessor properties on the context prototype: wrap them with `Object.getOwnPropertyDescriptor` / `Object.defineProperty`, keeping the original getter and setter. Per-canvas records are kept in a `WeakMap` when available, else on an array capped at 20.

- [ ] **Step 4: Run and see them pass, commit**

```bash
git commit -am "Add fingerprinting instrumentation script (fresh load only)"
```

---

### Task 2: Carry the report from the fresh load into the store, and judge it

**Files:**
- Create: `lib/models/inspection/technique_signals.dart`
- Create: `lib/services/derive/techniques.dart`
- Modify: `lib/services/collectors/fresh_load_measurer.dart` (`FreshLoadRaw`, second user script, one more `evaluateJavascript`)
- Modify: `lib/models/inspection/page_inspection.dart`, `lib/services/inspection_store.dart` (`applyFreshLoad`), `lib/services/html_service.dart` (`measureFreshLoad` ~4954)
- Test: `test/derive/techniques_test.dart`, `test/services/html_service_fresh_load_test.dart`

**Interfaces:**
- Produces:

```dart
class CanvasRead { final int width, height, chars, colors, reads; final String script; }
class TechniqueSignals {
  final List<CanvasRead> canvas;
  final int fontMeasureCalls, distinctFonts;
  final bool webglDebugInfo;
  final int audioOffline, audioOscillators, audioRendered;
  final int rtcConnections, rtcDataChannels, rtcOffers, rtcGetUserMedia;
  final int enumerateDevices, battery, clipboardRead;
  final List<PromptCall> prompts;         // api, at (Duration), userActive (bool?), script
  final Map<String, String> scripts;      // signal group → script URL ('' unknown)
}
Observed<TechniqueSignals> parseTechniqueReport(Object? raw);

enum TechniqueSeverity { high, medium, low }
class TechniqueFinding {
  final String id;
  final TechniqueSeverity severity;
  final String title;
  final String detail;
  final List<String> scripts;   // hosts or URLs involved
  final DataSource source;
  Map<String, Object?> toJson();
}
List<TechniqueFinding> judgeSignals(TechniqueSignals s);
```

- `FreshLoadRaw` gets `final Object? techniques`. `PageInspection.freshTechniques` is `Observed<TechniqueSignals>`, default `Unavailable(notApplicable, 'Run a fresh load to check')`; set by `InspectionStore.applyFreshLoad(gen, result, {screenshot, techniques})`; `Pending` while the load runs; `Unavailable(unsupportedPlatform)` where there is no headless WebView.
- The measurer adds a second `UserScript` with `vsvTechniquesJs` in the page world (no `contentWorld`), `AT_DOCUMENT_START`, `forMainFrameOnly: true`, and reads `window.__vsv_tech_report && window.__vsv_tech_report()` in the page world right before the collect.

Rules of `judgeSignals` (constants in `techniques.dart`):

| id | severity | when | title |
|---|---|---|---|
| `canvas-fingerprint` | high | a canvas with `width ≥ 16`, `height ≥ 16`, `reads ≥ 1` and (`chars ≥ 10` or `colors ≥ 2`) | `Reads back a canvas it drew text on (canvas fingerprinting)` |
| `font-probing` | medium | `distinctFonts ≥ 50` | `Measures text in N different fonts (font probing)` |
| `webgl-fingerprint` | medium | `webglDebugInfo` | `Reads the graphics card's vendor and model` |
| `audio-fingerprint` | high | `audioOffline ≥ 1`, `audioOscillators ≥ 1`, `audioRendered ≥ 1` | `Renders a silent audio signal and reads it back (audio fingerprinting)` |
| `webrtc-probe` | medium | `rtcConnections ≥ 1`, (`rtcDataChannels ≥ 1` or `rtcOffers ≥ 1`), `rtcGetUserMedia == 0` | `Opens a WebRTC connection without a call (can reveal local addresses)` |
| `device-enumeration` | low | `enumerateDevices ≥ 1` | `Lists cameras and microphones` |
| `battery` | low | `battery ≥ 1` | `Reads the battery status` |
| `clipboard-read` | high | `clipboardRead ≥ 1` | `Reads the clipboard` |
| `prompt-on-load` | medium | each prompt with `userActive == false` | `Asks for <api> without a click, N s after loading` |

The canvas thresholds follow the heuristic of Englehardt and Narayanan, "Online Tracking: A 1-million-site Measurement and Analysis" (2016), as I recall it: size at least 16×16, text with at least ten distinct characters or two colours, then read back. Read §6.1 of the paper before coding; where it differs, the paper wins and the constants and tests change with it.

- [ ] **Step 1: Write the failing tests**

```dart
test('text in two colours read back is a canvas fingerprint', () {
  final f = judgeSignals(signals(canvas: [
    const CanvasRead(width: 300, height: 150, chars: 34, colors: 2, reads: 1,
        script: 'https://cdn.fp.test/fp.js')]));
  expect(f.single.id, 'canvas-fingerprint');
  expect(f.single.severity, TechniqueSeverity.high);
  expect(f.single.scripts, ['https://cdn.fp.test/fp.js']);
});
test('a chart is not a fingerprint', () {
  expect(judgeSignals(signals(canvas: [
    const CanvasRead(width: 800, height: 400, chars: 0, colors: 1, reads: 3, script: '')])),
      isEmpty);
});
test('a tiny canvas is not a fingerprint', () { /* 8×8 with text and read → empty */ });
test('a video call is not a WebRTC probe', () { /* connections 1, offers 1, getUserMedia 1 → empty */ });
test('a prompt after a click is not reported', () { /* userActive true → empty */ });
test('report parsing', () {
  expect(parseTechniqueReport(null), isA<Unavailable<TechniqueSignals>>());
  expect(parseTechniqueReport('not json'), isA<Failed<TechniqueSignals>>());
  // the JSON of Task 1's interface block → Present with distinctFonts 96
});
// html_service_fresh_load_test.dart
test('the fresh load stores the technique signals', () async {
  // fake FreshLoadMeasurer returning FreshLoadRaw(payload, techniques: '<report json>')
  // expect service.store.current.freshTechniques is Present after measureFreshLoad()
});
test('before a fresh load the signals are unavailable with the hint', () {
  // expect Unavailable(notApplicable, 'Run a fresh load to check')
});
```

- [ ] **Step 2: Run, see them fail, implement, run the suite, commit**

Run: `flutter analyze --no-pub && flutter test`
```bash
git commit -am "Fresh load records fingerprinting signals; rules that judge them"
```

---

### Task 3: Checks from data the app already has: shared identifiers, missing SRI

**Files:**
- Modify: `lib/services/derive/techniques.dart`
- Modify: `lib/services/metadata_parser.dart` (one new key in the extracted map)
- Test: `test/derive/techniques_test.dart`, `test/services/metadata_followup_test.dart`

**Interfaces:**
- Consumes: `sameSite`, `registrableDomain`, `BrowserSnapshot.cookies`, `BrowserSnapshot.resources`.
- Produces: `List<TechniqueFinding> findSharedIdentifiers(BrowserSnapshot b)` and `TechniqueFinding? findMissingIntegrity(Map<String, dynamic> metadata)`.
- Produces (metadata): `metadata['subresourceIntegrity'] = {'thirdParty': <int>, 'without': [<url>, …]}`: `<script src>` and `<link rel="stylesheet" href>` whose host is not `sameSite` with the page; `without` = those lacking a non-empty `integrity` attribute (at most 100).

Rules:
- `id-sharing` (medium): a cookie whose value is at least `kIdMinLength` (16) characters, has at least 8 distinct characters, and appears (as is, or URL-encoded) in the URL of requests to at least `kIdMinParties` (2) different registrable domains other than the page's. Title: `The identifier in cookie <name> is sent to N other parties`. Detail lists the registrable domains (at most 5). `scripts` = those domains. One finding per cookie, at most 10.
- `no-sri` (low): `without` is not empty. Title: `N of M third-party scripts and stylesheets have no integrity check`. Detail: the first five hosts.

- [ ] **Step 1: Write the failing tests**

```dart
test('an identifier sent to two other parties is reported, without its value', () {
  const id = 'a1b2c3d4e5f6a7b8c9';
  final f = findSharedIdentifiers(snapshot(
    url: 'https://shop.test/',
    cookies: [cookie('_uid', value: id)],
    resources: [res('https://sync.ads-a.test/p?u=$id'), res('https://px.ads-b.test/m/$id'),
                res('https://shop.test/api?u=$id')]));
  expect(f.single.id, 'id-sharing');
  expect(f.single.title, 'The identifier in cookie _uid is sent to 2 other parties');
  expect(f.single.scripts, ['ads-a.test', 'ads-b.test']);
  expect('${f.single.toJson()}', isNot(contains(id)));
});
test('short and common values are never identifiers', () {
  for (final v in ['1', 'true', 'en', '1731628800', 'aaaaaaaaaaaaaaaaaaaa']) {
    // cookie value v sent to two other parties → no finding
  }
});
test('one other party is not sharing', () { /* only ads-a.test → empty */ });
test('missing integrity is counted on third-party files only', () {
  // metadata from an HTML with: own script without integrity, a third-party script with,
  // a third-party script without, a third-party stylesheet without
  // expect subresourceIntegrity == {'thirdParty': 3, 'without': [two urls]}
  // expect findMissingIntegrity(...)!.title ==
  //   '2 of 3 third-party scripts and stylesheets have no integrity check'
});
```

`snapshot`, `cookie`, `res` are the helpers in `test/derive/fixtures.dart` (extend `snapshot` if it lacks a parameter).

- [ ] **Step 2: Run, see them fail, implement, run the suite, commit**

```bash
git commit -am "Detect identifiers shared between parties and third-party files without SRI"
```

---

### Task 4: CNAME cloaking

**Files:**
- Create: `lib/services/cname_cloaking_service.dart`
- Modify: `lib/services/sovereignty_service.dart` (make the DoH query reusable; CNAME answers)
- Modify: `PRIVACY.md` (the DoH line: also when the Privacy tab is open)
- Test: `test/services/cname_cloaking_service_test.dart`, `test/services/sovereignty_service_test.dart`

**Interfaces:**
- Produces: `static Future<List<String>?> SovereigntyService.dnsQuery(String domain, int type)` (public name for today's `_dnsQuery`); `parseDnsRecords(d, 5)` returns the alias targets as lower-case host names without the trailing dot. Read `parseDnsRecords` first: add type 5 only if it is not handled.
- Produces:

```dart
class CnameAlias {
  final String host;       // metrics.shop.test
  final String target;     // shop.sc.omtrdc.net
  final String tracker;    // catalogue entity name
  const CnameAlias(this.host, this.target, this.tracker);
}
class CloakingResult {
  final List<CnameAlias> aliases;
  final List<String> checked;
  final List<String> notChecked;   // lookup failed
}
typedef CnameLookup = Future<List<String>?> Function(String host);

/// Hosts of [resourceHosts] on the page's own site (same registrable domain,
/// not the page host itself), at most [max]; each is looked up once.
Future<CloakingResult> findCloakedTrackers(Iterable<String> resourceHosts,
    {required String pageHost, required CnameLookup lookup, int max = 20});
```

  A host is an alias for a tracker when a CNAME target is not `sameSite` with the page and `entityForHost(target)` is an entity with `category.isTracking`. A target with no catalogue entity is not reported (aliasing to a CDN is normal).
- `HtmlService`: `Observed<CloakingResult> get cnameCloaking` and `void watchCloaking(bool watching)`: the lookup runs once per navigation, after `browserSettled`, only while a view watches (same pattern as `watchSovereignty`); results are dropped when the navigation moved on.

- [ ] **Step 1: Write the failing tests**

```dart
test('a first-party host that is an alias for a tracker is found', () async {
  final r = await findCloakedTrackers(
      ['metrics.shop.test', 'cdn.shop.test', 'www.shop.test', 'ads.other.test'],
      pageHost: 'www.shop.test',
      lookup: (h) async => switch (h) {
            'metrics.shop.test' => ['shop.sc.omtrdc.net'],
            'cdn.shop.test' => ['d111.cloudfront.net'],
            _ => const <String>[],
          });
  expect(r.checked, ['metrics.shop.test', 'cdn.shop.test']);
  expect(r.aliases.single.host, 'metrics.shop.test');
  expect(r.aliases.single.tracker, isNotEmpty);
});
test('a failed lookup is listed as not checked, the rest still runs', () async {
  // lookup returns null for one host → notChecked == [that host], other alias still found
});
test('at most 20 hosts are looked up', () async { /* 30 subdomains → checked.length == 20 */ });
```

Use a target host that the catalogue maps to a tracking entity; check with `grep -n "omtrdc\|hosts:" lib/services/detection/catalog.dart` and pick a real one if `omtrdc.net` is not listed.

- [ ] **Step 2: Run, see them fail, implement, run the suite, commit**

```bash
git commit -am "Detect trackers hidden behind a first-party hostname (CNAME cloaking)"
```

---

### Task 5: `deriveTechniques`, the Privacy tab section, export, summary

**Files:**
- Modify: `lib/services/derive/techniques.dart`
- Modify: `lib/services/html_service.dart` (getter `techniquesView`)
- Create: `lib/widgets/techniques_section.dart`; Modify: `lib/widgets/privacy_view.dart` (section under the tracker list)
- Modify: `lib/services/inspection_export_service.dart` (`analysis/techniques.json`)
- Modify (when plan 02 is merged): `lib/services/derive/inspection_summary.dart`
- Test: `test/derive/techniques_test.dart`, `test/widgets/techniques_section_test.dart`

**Interfaces:**
- Produces:

```dart
class TechniquesModel {
  final List<TechniqueFinding> findings;     // high first, then rule order
  /// Why the call-based checks have no result (not measured, running,
  /// unsupported, failed); null when they ran.
  final String? callChecksNote;
  final bool callChecksCanRun;               // show the 'Run fresh load' button
  final List<String> notChecked;             // e.g. hosts whose DNS lookup failed
}
TechniquesModel deriveTechniques(PageInspection p,
    {required Observed<CloakingResult> cloaking, Map<String, dynamic>? metadata});
```

- Section layout: heading `Techniques`; the findings as tiles (severity dot, title, detail, the scripts' hosts); when `callChecksNote != null` a row with that note and, when `callChecksCanRun`, a button `Run fresh load` that calls `HtmlService.measureFreshLoad`; when there are no findings and every check ran: `No suspicious techniques seen by the checks that ran.` The section calls `watchCloaking(true)` in `initState` and `false` in `dispose`.
- Export: `analysis/techniques.json` = `{'callChecks': <observedJson of freshTechniques as a status only>, 'findings': [toJson…], 'notChecked': […]}`, wrapped by `unlessBlocked`.
- Summary rules (plan 02, appended after `trackers`): one finding per technique finding of severity high, id `technique-<id>`, severity high, the same title, tab `privacy`.
- Batch: `BatchOptions.freshLoad` already triggers `measureFreshLoad()`; nothing more to do.

- [ ] **Step 1: Write the failing tests**

```dart
test('without a fresh load the call checks say so, data checks still run', () {
  final m = deriveTechniques(pageWithSharedId,
      cloaking: const Pending(), metadata: null);
  expect(m.callChecksNote, 'Run a fresh load to check');
  expect(m.callChecksCanRun, isTrue);
  expect(m.findings.map((f) => f.id), ['id-sharing']);
});
test('unsupported platform: note without a button', () {
  // freshTechniques Unavailable(unsupportedPlatform) → callChecksCanRun false
});
test('findings are ordered by severity', () { /* high before medium before low */ });
testWidgets('the section offers the fresh load when it has not run', (tester) async {
  // expect find.text('Run fresh load'), find.text('Run a fresh load to check')
});
testWidgets('no findings after all checks ran', (tester) async {
  // expect find.text('No suspicious techniques seen by the checks that ran.')
});
```

- [ ] **Step 2: Run, see them fail, implement, run the suite**

Run: `flutter analyze --no-pub && flutter test`

- [ ] **Step 3: Real check (macOS)**

Open `https://browserleaks.com/canvas` in the app, open Privacy, press `Run fresh load`.
Expected: after the fresh load a `canvas-fingerprint` finding appears. Then open `https://example.com`, run the fresh load: `No suspicious techniques seen by the checks that ran.`

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Privacy tab: suspicious techniques (fingerprinting, shared identifiers, cloaking, SRI)"
```

---

## Final gate

- [ ] `flutter analyze --no-pub && flutter test`: clean, all pass.
- [ ] `validation/run.sh example kvk`: no new deviations (the live browser was not touched).
- [ ] `CHANGELOG.md` entry; one line in the README feature list.
