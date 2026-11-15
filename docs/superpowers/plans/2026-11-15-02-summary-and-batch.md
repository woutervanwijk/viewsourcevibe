# Summary and Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A rule-based summary of the most important findings of an inspection, and a batch mode that visits a list of sites one by one and exports every site's inspection package plus that summary in one zip (F1).

**Architecture:** `deriveSummary` is a pure function over the models the tabs already use; it feeds the report, a new `analysis/summary.json`, and the batch table. `BatchRunner` drives the live browser through a narrow `BatchTarget` interface (so it is testable without a WebView), the way `integration_test/site_validation_test.dart` already does by hand. No AI, no new dependencies.

**Tech Stack:** Flutter, `provider`, `archive` (already a dependency), `shared_preferences`.

**Spec:** `docs/audits/2026-11-15-explorer-audit.md` (F1). Requirements from the owner (14 Nov): fill in a list of sites; they get visited one by one; results exported like the current export, plus a summary with the most important findings per site; no AI.

**Depends on:** plan 01 Task 6 (`sameSite`) and Task 9 (`PageWeight.breakdown` keys). Start after those are merged.

## Global Constraints

- Everything in plan 01's Global Constraints applies.
- Unknown is never `0` or `''` in JSON: a fact that is unknown is `null`. In CSV an unknown fact is an empty cell.
- Text that comes from a site (finding details, tracker names from cookies, block-page text) is escaped in HTML and neutralised in CSV (see Task 3).
- Rules are fixed and deterministic: the same inspection gives the same findings in the same order.
- The thresholds below are product choices without an external norm; they live in one place (`inspection_summary.dart`) as named constants.

## Review Focus

1. A site that never settles: after the timeout the package is still exported, the row says `timed out` and names the analyses that were unfinished (Task 4 test `a site that never settles is exported as timed out`).
2. Two URLs with the same slug (`example.com/a`, `example.com/a/`): package names stay unique (Task 4 test `slugs are unique`).
3. Site-controlled text starting with `=`, `+`, `-` or `@` in a CSV cell (formula injection): prefixed with `'` (Task 3 test).
4. Cancel during a site: the runner stops, finished sites and their packages are kept, the zip can still be built (Task 4 test `cancel keeps finished sites`).
5. Pasted input with blank lines, `#` comments, bare domains, duplicates and non-web schemes (`javascript:`, `file:`) (Task 4 test `parseBatchInput`).
6. A block or challenge page: findings about the site's content (trackers, cookies, weight) are not reported for it (Task 1 test `a block page hides content findings`).

---

### Task 1: `deriveSummary`: fixed rules over the existing models

**Files:**
- Create: `lib/services/derive/inspection_summary.dart`
- Test: `test/derive/inspection_summary_test.dart`

**Interfaces:**
- Consumes: `PageInspection`, `Observed<GeneralModel>`, `Observed<SecurityModel>`, `Observed<CookiesModel>`, `DetectionsView`, `Observed<SovereigntyReport>`, `BlockPage?`, `List<Divergence>`, `derivePageWeight`, `sameSite`.
- Produces:

```dart
enum FindingSeverity { high, medium, low, info }

class Finding {
  final String id;            // rule id from the table below
  final FindingSeverity severity;
  final String title;         // one line, complete on its own
  final String? tab;          // AppTab.tag of the tab with the detail
  const Finding(this.id, this.severity, this.title, {this.tab});
  Map<String, Object?> toJson();
}

class SummaryInputs {
  final PageInspection inspection;
  final Observed<GeneralModel> general;
  final Observed<SecurityModel> security;
  final Observed<CookiesModel> cookies;
  final DetectionsView detections;
  final Observed<SovereigntyReport> sovereignty;
  final BlockPage? blockPage;
  final List<Divergence> divergences;
  const SummaryInputs({required ...all of them});
}

class InspectionSummary {
  final List<Finding> findings;        // sorted: severity, then rule order
  final Map<String, Object?> facts;    // keys in [summaryFactKeys], null = unknown
  List<Finding> get top => findings.take(5).toList();
  Map<String, Object?> toJson();       // {'findings': [...], 'facts': {...}}
}

const List<String> summaryFactKeys = [
  'url', 'finalUrl', 'status', 'blocked', 'requests', 'thirdPartyHosts',
  'transferBytes', 'transferIsLowerBound', 'trackers', 'trackerNames',
  'consentTool', 'cookies', 'advertisingCookies', 'analyticsCookies',
  'securityHeadersPct', 'cspScore', 'certValidUntil',
  'sovereigntyScore', 'sovereigntyGrade', 'sovereigntyCoverage',
];

InspectionSummary deriveSummary(SummaryInputs i);
```

Rules, in rule order. "Trackers" = detections with `category.isTracking` that are not `hintOnly`. A rule whose input is not `Present` produces nothing.

| id | severity | when | title | tab |
|---|---|---|---|---|
| `block-page` | high | `blockPage != null` | `Not the site: <blockPage.detail>` | `browser` |
| `invalid-cert-accepted` | high | server snapshot `acceptedInvalidCertificate` | `Loaded with an untrusted certificate (accepted by the user)` | `security` |
| `no-https` | high | final URL scheme is `http` | `No HTTPS: the page is served over plain HTTP` | `security` |
| `cert-expired` | high | `certificate.validityExpired` | `Certificate expired (<validUntil>)` | `security` |
| `cert-host` | high | `!certificate.hostMatches` | `Certificate does not match the host` | `security` |
| `pre-consent` | high | not blocked; a detection with category `consent` exists and ≥ 1 tracker has `requests > 0` or a cookie | `Tracking before consent: N tracker(s) active while <consent tool> is present` | `privacy` |
| `trackers` | high when a tracker has `category.tracking >= 4`, else medium | not blocked; ≥ 1 tracker | `N tracker(s): A, B, C` (first three by the engine's order, then ` (+k)`) | `privacy` |
| `ad-cookies` | medium | not blocked; `cookies.advertisingCount > 0` | `N advertising cookie(s) set without a consent choice` | `cookies` |
| `cert-expiring` | medium | not expired and `validityTone` is `warn` or `bad` | `Certificate: <validityLabel>` | `security` |
| `security-headers` | medium below `kHeadersPoor` (50), low below `kHeadersGood` (80) | `audit.percentage != null` | `Security headers: P% (missing: <labels of applicable failing checks>)` | `security` |
| `page-weight` | medium above `kWeightHeavy` (5 MB), low above `kWeightNotable` (2 MB) | not blocked; `PageWeight.transfer != null` | `Page weight <prefix><size>` plus `, P% in third-party iframes` when that share is ≥ 20% | `page-size` |
| `sovereignty` | medium for grade `Poor`, low for `Fair` | `report.grade != null` | `Sovereignty: S (<grade>), coverage C%` | `sovereignty` |
| `csp-weak` | low | `csp.score != null && csp.score < 50` | `Content-Security-Policy is weak (score S)` | `security` |
| `divergence` | low | each divergence with `!lowSeverity` | `<divergence.message>` | `probe` |
| `third-parties` | info | not blocked; browser resources Present | `N third-party host(s) contacted` | `request-timeline` |

Sizes use `FormatUtils` (the same formatter the Size tab uses). Third-party host = host of a resource that is not `sameSite` with the page host; counted once per host.

- [ ] **Step 1: Write the failing tests**

Build inputs from the existing fixtures (`test/fixtures/inspection/trackers.dart`, `full_page.dart`, `bot_blocked.dart`) and the derive functions the views use; add a small helper `SummaryInputs inputsFor(PageInspection p, {List<Detection> detections})` in the test file.

```dart
test('trackers are reported with names and severity', () {
  final s = deriveSummary(inputsFor(trackersPage, detections: [
    Detection(entityNamed('Google Ads')!)..requests = 2,
    Detection(entityNamed('Google Analytics')!)..requests = 1,
  ]));
  final f = s.findings.firstWhere((f) => f.id == 'trackers');
  expect(f.severity, FindingSeverity.high); // advertising has tracking 5
  expect(f.title, '2 tracker(s): Google Ads, Google Analytics');
  expect(s.facts['trackers'], 2);
});
test('tracking with a consent tool present is pre-consent tracking', () {
  // + Detection(entityNamed('Cookiebot')!)..requests = 1
  // expect a finding 'pre-consent' with severity high whose title contains 'Cookiebot'
  // expect facts['consentTool'] == 'Cookiebot'
});
test('a block page hides content findings', () {
  final s = deriveSummary(inputsFor(botBlockedPage, detections: [
    Detection(entityNamed('Google Ads')!)..requests = 2]));
  expect(s.findings.first.id, 'block-page');
  expect(s.findings.map((f) => f.id), isNot(contains('trackers')));
  expect(s.facts['blocked'], isTrue);
  expect(s.facts['trackers'], isNull);
});
test('unknown facts are null, never 0', () {
  final s = deriveSummary(inputsFor(const PageInspection.empty()));
  expect(s.findings, isEmpty);
  expect(s.facts.keys, summaryFactKeys);
  expect(s.facts['requests'], isNull);
  expect(s.facts['securityHeadersPct'], isNull);
});
test('findings are sorted by severity, then rule order', () {
  // full page with trackers (high), weak headers (medium), info
  // expect severities non-decreasing by index
});
test('security headers name what is missing', () {
  // audit with HSTS and CSP failing out of six applicable checks
  // expect title 'Security headers: 67% (missing: HSTS, CSP)' with severity low
});
```

Use the catalogue's real entity names; check them with `grep "Entity('" lib/services/detection/catalog.dart`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/derive/inspection_summary_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement `inspection_summary.dart`**

One private function per rule returning `Finding?` or `List<Finding>`, called in table order; a stable sort by `severity.index` afterwards. Thresholds as top-level constants `kHeadersPoor = 50`, `kHeadersGood = 80`, `kWeightHeavy = 5 * 1024 * 1024`, `kWeightNotable = 2 * 1024 * 1024`, `kFrameShareNotable = 0.20`.

- [ ] **Step 4: Run and see them pass, commit**

```bash
git add lib/services/derive/inspection_summary.dart test/derive/inspection_summary_test.dart
git commit -m "Add a rule-based inspection summary (key findings)"
```

---

### Task 2: The summary in the single-site export

**Files:**
- Modify: `lib/services/html_service.dart` (one getter next to `generalView` ~837)
- Modify: `lib/services/inspection_export_service.dart` (`buildPackageBytes`, `_buildHtmlReport`)
- Test: `test/inspection_export_service_test.dart`

**Interfaces:**
- Produces: `InspectionSummary get summary` on `HtmlService` (builds `SummaryInputs` from its existing getters; no caching).
- Produces: `analysis/summary.json` in the package (`summary.toJson()`); a `Key findings` section directly under the first metric cards in `report.html`: a table with columns `Severity`, `Finding`, or the card `No findings from the checks that ran.` when empty.

- [ ] **Step 1: Write the failing test**

```dart
test('the package carries the summary', () {
  final archive = ZipDecoder().decodeBytes(
      InspectionExportService().buildPackageBytes(service));
  final json = jsonDecode(utf8.decode(
      archive.findFile('analysis/summary.json')!.content as List<int>));
  expect(json['facts'].keys, containsAll(summaryFactKeys));
  final report = utf8.decode(archive.findFile('report.html')!.content as List<int>);
  expect(report, contains('<h2>Key findings</h2>'));
});
```

`service` is set up the way the other tests in this file do it.

- [ ] **Step 2: Run, see it fail, implement, run the suite, commit**

Run: `flutter test test/inspection_export_service_test.dart`
```bash
git commit -am "Export: key findings in report.html and analysis/summary.json"
```

---

### Task 3: Batch outputs: `summary.json`, `summary.csv`, `summary.html`

**Files:**
- Create: `lib/services/batch_summary.dart`
- Test: `test/services/batch_summary_test.dart`

**Interfaces:**
- Produces:

```dart
class BatchRow {
  final Uri url;
  final String slug;          // also the package name: sites/<slug>.zip
  final String state;         // 'done' | 'timed out' | 'failed' | 'cancelled'
  final List<String> pending; // analyses unfinished at export
  final String? error;
  final InspectionSummary? summary; // null when nothing was exported
  const BatchRow({...});
}

Map<String, Object?> batchSummaryJson(List<BatchRow> rows, {required DateTime exportedAt});
String batchSummaryCsv(List<BatchRow> rows);
String batchSummaryHtml(List<BatchRow> rows, {required DateTime exportedAt});
String csvCell(Object? value);
```

- `batchSummaryCsv`: header `url,state,pending,error,` + `summaryFactKeys` joined by `,` + `,finding1,finding2,finding3,finding4,finding5`. One row per site, `\r\n` line ends, UTF-8.
- `csvCell`: null → empty; lists joined with `; `; a cell whose first character is `=`, `+`, `-`, `@`, tab or CR gets a leading `'`; cells containing `,`, `"`, CR or LF are quoted with `"` doubled. Numbers and booleans are written as they are (a negative number is a number, not text, and gets no `'`).
- `batchSummaryHtml`: one self-contained page (reuse the CSS string of the report: make `InspectionExportService._reportCss` a library-level `const reportCss` in its own file `lib/services/report_css.dart`). A table with one row per site: site (link to `sites/<slug>.zip`), state, and the top five findings as a list with the severity as a word. Everything escaped with `HtmlEscape`.
- `batchSummaryJson`: `{'format': 'view-source-vibe-batch', 'formatVersion': 1, 'exportedAt': ..., 'unknownIs': 'null', 'sites': [{'url', 'slug', 'package', 'state', 'pending', 'error', 'summary'}]}`.

- [ ] **Step 1: Write the failing tests**

```dart
test('csv cells from a site cannot become formulas', () {
  expect(csvCell('=HYPERLINK("http://x")'), '"\'=HYPERLINK(""http://x"")"');
  expect(csvCell('@cmd'), "'@cmd");
  expect(csvCell(-5), '-5');
  expect(csvCell(null), '');
  expect(csvCell(['a', 'b']), 'a; b');
  expect(csvCell('a,b'), '"a,b"');
});
test('csv has one row per site and a stable header', () {
  final csv = batchSummaryCsv([rowFor('https://a.test/'), rowFor('https://b.test/')]);
  final lines = csv.trimRight().split('\r\n');
  expect(lines, hasLength(3));
  expect(lines.first, startsWith('url,state,pending,error,url,finalUrl,status,'));
  expect(lines.first, endsWith('finding1,finding2,finding3,finding4,finding5'));
});
test('html escapes site text', () {
  // a row whose finding title is '<script>alert(1)</script>'
  // expect the page to contain '&lt;script&gt;' and not '<script>alert'
});
test('a failed site has a row without a summary', () {
  // BatchRow(state: 'failed', error: 'timeout', summary: null)
  // csv row has empty fact cells; json 'summary' is null
});
```

- [ ] **Step 2: Run, see them fail, implement, run, commit**

Run: `flutter test test/services/batch_summary_test.dart`
```bash
git commit -am "Batch: summary as JSON, CSV and HTML"
```

---

### Task 4: `BatchRunner`: one site at a time through the live browser

**Files:**
- Create: `lib/services/batch_runner.dart`
- Modify: `integration_test/site_validation_test.dart` (use `pendingAnalyses`, delete its private `_pending`)
- Test: `test/services/batch_runner_test.dart`

**Interfaces:**
- Consumes: `InspectionSummary`, `BatchRow`, `batchSummary*` (Tasks 1, 3).
- Produces:

```dart
/// Unfinished analyses by name; empty when the page is ready to export.
List<String> pendingAnalyses(HtmlService s);   // moved from the integration test

/// One URL per line. Blank lines and lines starting with '#' are skipped; a
/// line without a scheme gets 'https://'. Only http/https with a host
/// survive (a line with whitespace inside it is rejected); duplicates
/// (after normalising) are dropped; at most [max].
({List<Uri> urls, List<String> rejected}) parseBatchInput(String text, {int max = 50});

class BatchOptions {
  final bool clearSiteData;   // default true
  final Duration timeout;     // default 90 s
  final Duration linger;      // default 5 s
  final bool freshLoad;       // default false (plan 04 uses it)
  const BatchOptions({...});
}

abstract interface class BatchTarget {
  Future<void> open(Uri url);
  List<String> pending();
  void collectLate();
  Future<void> clearSiteData(Uri url);
  Future<void> measureFreshLoad();
  void watchSovereignty(bool watching);
  InspectionSummary summary();
  List<int> package();
}

class HtmlServiceBatchTarget implements BatchTarget {
  HtmlServiceBatchTarget(HtmlService service);
}

class BatchRunner extends ChangeNotifier {
  BatchRunner(BatchTarget target,
      {Duration poll = const Duration(milliseconds: 500),
       Future<Directory> Function()? workDir});
  bool get running;
  int get index;                 // site being visited, 0-based
  int get total;
  Uri? get currentUrl;
  List<String> get currentPending;
  List<BatchRow> get rows;       // finished sites so far
  Future<void> run(List<Uri> urls, {BatchOptions options = const BatchOptions()});
  void cancel();
  /// Writes the batch zip and returns it. Null when no site finished.
  Future<File?> writeZip();
}
```

Per site, in this order: `clearSiteData` (when the option is on); `open(url)`; wait 2 s; poll `pending()` every `poll` until empty or `timeout`; wait `linger`, call `collectLate()`, wait 3 s; `measureFreshLoad()` when the option is on; then `package()` and `summary()`. The package bytes are written at once to `<workDir>/sites/<slug>.zip` and not kept in memory. An exception from any step makes the row `failed` with the error text and the runner continues with the next site. `watchSovereignty(true)` at the start of `run`, `false` at the end (also after cancel or an exception).

`HtmlServiceBatchTarget.open` calls `loadFromUrl(url.toString(), switchToTab: HtmlService.browserTab)`. `clearSiteData` uses `site_data_cleaner.clearSiteData`. `collectLate` calls `onBrowserResourcesChanged()`. `package` calls `InspectionExportService().buildPackageBytes(service)`.

Slug: the same slug `InspectionExportService` uses for file names (make `_slugFor` public as `inspectionSlug`), with `-2`, `-3`, … appended on a clash.

`writeZip`: `viewsourcevibe-batch-<UTC stamp>.zip` in the work directory, containing `summary.html`, `summary.csv`, `summary.json` and `sites/<slug>.zip` for every exported site. Written with `ZipFileEncoder` from `package:archive/archive_io.dart` so the packages are streamed from disk; the nested zips are stored, not compressed again. Check the encoder's method names against `archive` 4.6 before writing the code.

- [ ] **Step 1: Write the failing tests**

A `FakeBatchTarget` records calls; `pendingFor` maps a host to how many polls it stays pending (`-1` = forever).

```dart
test('sites are visited one by one, in order', () async {
  final t = FakeBatchTarget();
  final r = BatchRunner(t, poll: const Duration(milliseconds: 1), workDir: tmp);
  await r.run([Uri.parse('https://a.test/'), Uri.parse('https://b.test/')],
      options: fast);
  expect(t.calls.where((c) => c.startsWith('open')),
      ['open https://a.test/', 'open https://b.test/']);
  expect(t.calls.indexOf('package https://a.test/'),
      lessThan(t.calls.indexOf('open https://b.test/')));
  expect(r.rows.map((x) => x.state), ['done', 'done']);
  expect(t.calls.first, 'watchSovereignty true');
  expect(t.calls.last, 'watchSovereignty false');
});
test('a site that never settles is exported as timed out', () async {
  // pendingFor['slow.test'] = -1, pending names ['sovereignty']
  // expect row.state == 'timed out', row.pending == ['sovereignty'], row.summary != null
});
test('a failing site does not stop the batch', () async {
  // t.failOpen = {'bad.test'}; expect states ['failed', 'done'] and error text on the first
});
test('cancel keeps finished sites', () async {
  // cancel() while the second site is pending
  // expect r.rows.length == 1, r.running == false, (await r.writeZip()) != null
});
test('slugs are unique', () async {
  // 'https://example.com/a' and 'https://example.com/a?x=1'
  // expect two different slugs, the second ending in '-2'
});
test('the zip holds the summary and one package per site', () async {
  final zip = ZipDecoder().decodeBytes((await r.writeZip())!.readAsBytesSync());
  expect(zip.files.map((f) => f.name), containsAll(
      ['summary.html', 'summary.csv', 'summary.json', 'sites/a-test.zip', 'sites/b-test.zip']));
});
test('parseBatchInput', () {
  final p = parseBatchInput('kvk.nl\n\n# comment\nhttps://kvk.nl/\n'
      'javascript:alert(1)\nfile:///etc/passwd\n  http://a.test/x  \nnot a url');
  expect(p.urls.map((u) => u.toString()), ['https://kvk.nl', 'http://a.test/x']);
  expect(p.rejected, ['javascript:alert(1)', 'file:///etc/passwd', 'not a url']);
});
```

`fast` = `BatchOptions(timeout: Duration(milliseconds: 50), linger: Duration.zero)`; the fixed waits (2 s, 3 s) are constructor parameters of `BatchRunner` with those defaults so the tests pass `Duration.zero`. Normalising for duplicates: lower-case host, an empty path and `/` are the same.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/services/batch_runner_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement `batch_runner.dart`; switch the integration test to `pendingAnalyses`**

- [ ] **Step 4: Run the suite, commit**

Run: `flutter analyze --no-pub && flutter test`
```bash
git commit -am "Batch: runner that visits sites one by one and writes one zip"
```

---

### Task 5: Batch screens

**Files:**
- Create: `lib/screens/batch_screen.dart`, `lib/widgets/batch_banner.dart`
- Modify: `lib/main.dart` (provider), `lib/widgets/toolbar.dart` (menu entry `Batch…` next to the export entry), `lib/screens/home_screen.dart` (banner above the tab bar)
- Test: `test/widgets/batch_screen_test.dart`, `test/widgets/batch_banner_test.dart`

**Interfaces:**
- Consumes: `BatchRunner`, `parseBatchInput`, `BatchOptions` (Task 4).
- `ChangeNotifierProvider<BatchRunner>` created in `main.dart` with `HtmlServiceBatchTarget(htmlService)`.

Behaviour:
- **Batch screen** (pushed from the toolbar menu). A multi-line text field with the hint `One site per line`, restored from and saved to the `shared_preferences` key `batch_urls`. Under it: `N site(s)` and, when lines were rejected, `K line(s) skipped: <first three>`. Switches: `Clear site data before each site` (on), `Also measure a fresh load (slower)` (off). Button `Start` (disabled with 0 sites): starts the runner and pops back to the home screen, Browser tab.
- **Banner** on the home screen while `running`: `Batch 3/10 · kvk.nl · waiting for sovereignty, cookies` (or `· exporting`) and a `Cancel` button. When finished and `rows` is not empty: `Batch done: N site(s)` with `Results` and `Dismiss`.
- **Results** (same screen file, second route): one tile per site: host, state, up to three findings; a `Share zip` / `Save zip` button that calls `writeZip()` and then shares or saves the file exactly as `Toolbar._exportInspectionPackage` does for a single package (mobile: `UnifiedSharingService.shareFile`; desktop: the downloads directory), after `confirmSharePackage` (plan 01 Task 15) when that function exists.
- While a batch runs, the URL bar and Reload are left alone; a navigation the user starts by hand makes the current site's row whatever it becomes. No locking.

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('the site count follows the text', (tester) async {
  await pumpBatchScreen(tester); // BatchRunner with a FakeBatchTarget
  await tester.enterText(find.byType(TextField), 'kvk.nl\njavascript:x\nexample.com');
  await tester.pump();
  expect(find.text('2 site(s)'), findsOneWidget);
  expect(find.textContaining('1 line(s) skipped'), findsOneWidget);
});
testWidgets('Start is disabled without sites', (tester) async { /* onPressed == null */ });
testWidgets('the banner shows progress and cancels', (tester) async {
  // runner mid-run on site 2 of 3 with pending ['sovereignty']
  // expect find.textContaining('Batch 2/3'), find.textContaining('waiting for sovereignty')
  // tap 'Cancel' → runner.running == false after pump
});
```

Move `FakeBatchTarget` from Task 4's test to `test/support/fake_batch_target.dart` so both tests share it.

- [ ] **Step 2: Run, see them fail, implement, run the suite**

Run: `flutter analyze --no-pub && flutter test`
Expected: PASS, including `test/architecture/no_data_logic_in_ui_test.dart` (the screen parses nothing itself; it calls `parseBatchInput`).

- [ ] **Step 3: Real run (macOS)**

Run: `flutter run -d macos`, open `Batch…`, paste `example.com`, `kvk.nl`, `rijksoverheid.nl`, start.
Expected: the three sites load one after another in the Browser tab; the banner counts 1/3 to 3/3; `Results` lists three rows; the saved zip opens and `summary.html` shows three rows whose links open the nested packages.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Batch: list of sites visited one by one, with results and one zip"
```

---

## Final gate

- [ ] `flutter analyze --no-pub && flutter test`: clean, all pass.
- [ ] `validation/run.sh example kvk` still works (it now uses `pendingAnalyses`).
- [ ] Add F1 to the changelog section for the next version in `CHANGELOG.md`, in the style of the existing entries.
