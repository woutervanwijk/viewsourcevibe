# Audit: structure, data correctness, security (15 Nov 2026)

Scope: everything the November score audits (`2026-11-berekeningen.md`, `2026-11-site-validatie.md`) did not cover: collectors, size attribution, export, WebView boundary, structure. Baseline: `flutter analyze` clean, 1389 tests pass.

Status per finding: **reproduced** (shown with a run) or **read** (follows from the code; needs a failing test before it is fixed).

The plans in `docs/superpowers/plans/2026-11-15-*.md` implement this document. IDs below are used there.

## D — Data correctness

| ID | Status | Finding | Where |
|---|---|---|---|
| D1 | reproduced (Node) | `__vsv_collect` calls `skip()`, which only exists inside the bootstrap closure. With one dropped resource the whole `resources` section becomes `{ok:false, error:"ReferenceError: skip is not defined"}`. The drop count is lost too, so the page weight is not marked as a lower bound. | `lib/services/collectors/vsv_collect_js.dart:359` |
| D2 | read | Own size lookups treat every `img` as safe to repeat. A cross-origin tracking pixel without Timing-Allow-Origin has no size, so the app sends its own HEAD/GET with the same query. That can double-count pageviews or conversions. | `lib/services/derive/estimate_targets.dart:16` |
| D3 | read | Size matching tier 4 keys on filename + query only (no host, no path): `a.com/x/logo.png` gets the size of `b.com/y/logo.png`. Tier 5 keys on host + last path segment and is shown as measured. | `lib/services/html_service.dart:4507`, `:4560` |
| D4 | read | The HTML document's weight comes from the app's own fetch (own User-Agent, gzip only) and is counted as measured. `PerformanceNavigationTiming` has `transferSize`, `encodedBodySize`, `decodedBodySize`; the collector does not read them. | `lib/services/derive/page_weight.dart:268`, `vsv_collect_js.dart:375` |
| D5 | read | `categorizeResource` falls back to URL substrings: `/lifestyle/api` → CSS, `/subscriptions` → script, anything with `document` → HTML. Video and audio are counted as images, fonts as other. | `lib/services/probe_service.dart:148` |
| D6 | read | The collector lives in the page's own JavaScript world (`window.__vsv_*`, patched `fetch`/`XHR`). A page can fake the data; anti-bot scripts can see the patch. Possibly related to open item O1 (bol.com block page); that link is a hypothesis. | `vsv_collect_js.dart:200` |
| D7 | read | `source/diff.patch` compares line N with line N. One inserted line marks every later line as changed. | `lib/services/inspection_export_service.dart:752` |
| D8 | read | Three definitions of "same site": detection engine (`_sameSite`), Sovereignty (`registrableDomain` with a short suffix list), site-data cleaner. `www.x.nl` and `static.x.nl` are different sites in the engine. | `lib/services/detection/engine.dart:109`, `sovereignty_service.dart:1511` |
| D9 | read | Detection confidence (92/90/88/82/72/40) reads like a percentage but has no basis. Cookie rules: first match wins, not the longest prefix. | `engine.dart:34`, `:222` |
| D10 | read | Only the first resolved IP of a host is used, and for anycast CDNs the GeoLite country is not where the visitor is served. Nothing marks that. | `sovereignty_service.dart:1408`, `:822` |

## S — Security and privacy

| ID | Finding | Where |
|---|---|---|
| S1 | `PRIVACY.md` says URLs never go to third parties. Hostnames and IPs go to RIPEstat, LibreDNS / Google DNS and DuckDuckGo's icon service, and the app makes its own requests to third-party resource hosts. | `PRIVACY.md` |
| S2 | Iframes post their resource URLs to the top frame with `postMessage(…, '*')`. The embedding page can read what a cross-origin frame loaded; any frame can inject fake entries. | `vsv_collect_js.dart:136` |
| S3 | Reader view renders Readability output with JavaScript on and no CSP. Readability removes `<script>` but not inline handlers. | `lib/services/reader_service.dart:302` |
| S4 | The iOS/macOS WebView plugin comes from a personal fork (`wangqiang1588/flutter_inappwebview`), pinned by commit. | `pubspec.yaml` |
| S5 | The export redacts cookie and storage values, but `source/browser-dom.html` and timeline URLs can hold personal data and tokens. No warning at share time. | `lib/widgets/toolbar.dart:192` |
| S6 | `debugPrint` also prints in release builds; there are 250 calls. The deep-link handler logs the full shared text. | `lib/main.dart:100` |
| S7 | RIPEstat calls carry no `sourceapp` parameter (their usage rules ask for one, as I recall; check their docs). | `sovereignty_service.dart:1448` |

## Q — Structure, performance, slop

| ID | Finding | Where |
|---|---|---|
| Q1 | `HtmlService` is 5454 lines: navigation, editor widgets, search, sovereignty scheduling, size enrichment, ~600 lines of language mapping (duplicate of `SourceViewerEditor`), filename guessing. | `lib/services/html_service.dart` |
| Q2 | Two data models: the typed `Observed` store, and a metadata `Map<String, dynamic>` mutated in place (113 such maps, 40 `_pageMetadata[...]` accesses) plus "legacy" adapters. | `html_service.dart:4473–4750` |
| Q3 | A new `HttpClient` per request: up to 400 size lookups and ~120 RIPEstat calls each open their own TLS connection. | `transfer_size_lookup.dart:33`, `sovereignty_service.dart:1430` |
| Q4 | Regexes compiled inside loops (header rules, beacons). | `engine.dart:300`, `:494` |
| Q5 | localStorage values cross the JS bridge on every poll; only keys and byte counts are used. | `vsv_collect_js.dart:387` |
| Q6 | Dead or stray code: `utils/page_weight.dart` (`resourcesBySize`, only its test uses it), `loadServerSourceForDiff`, `cancelPendingHighlight`, `HtmlService.getLanguageForExtension` (only tests), Dutch certificate dialog, version hard-coded in three places, `avoid_print: ignore` project-wide. | several |

## F — New datapoints

| ID | Feature | Plan |
|---|---|---|
| F1 | Rule-based summary of the most important findings per site; batch: a list of sites visited one by one, exported like the current package plus that summary. No AI. | 02 |
| F2 | Permissions insight: declared (Permissions-Policy, iframe `allow`), requested (camera, microphone, location), stored (quota, IndexedDB, Cache Storage, service workers). | 03 |
| F3 | Suspicious techniques: canvas / WebGL / audio fingerprinting, WebRTC probing, permission prompts on load (instrumented in the separate fresh load only), plus checks that need no instrumentation: CNAME cloaking, cookie syncing, third-party scripts without SRI, tracking before consent. | 04 |
| F4 | Structural view: a segmented wireframe of the rendered page, coloured by owner or element type. | 05 |

## Not in the plans (decisions for the owner)

- S4: fork `flutter_inappwebview` to your own account and point `dependency_overrides` at it. Needs your GitHub account.
- Q1 beyond the two mechanical extractions in plan 01: splitting `HtmlService` into navigation / editor / analysis controllers needs its own design.
- Q2: moving metadata from maps to typed models. Plan 01 only moves the size matching out; the rest is a separate migration.
- The open decisions from `2026-11-berekeningen.md` §3 (weights, thresholds) are unchanged.
