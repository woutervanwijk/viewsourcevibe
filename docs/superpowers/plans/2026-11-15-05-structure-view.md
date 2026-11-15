# Structure View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Structure tab that draws the rendered page as a segmented wireframe: landmarks, frames, media and large blocks at their real position and size, coloured by who owns them or by element type, with the heading outline beside it (F4).

**Architecture:** The collector measures boxes once the page has settled (`window.__vsv_layout()`, in the collector's world; it reads layout, changes nothing). A typed `PageLayout` goes into the store. `deriveStructure` classifies each block (page, own frame, third party, advertising, social) with the detection catalogue and builds the outline and notes. The widget only paints and hit-tests through pure functions.

**Tech Stack:** Flutter `CustomPaint`, collector JavaScript, `provider`.

**Spec:** `docs/audits/2026-11-15-explorer-audit.md` (F4). Owner's wording: "structural view. Like a dom tree, but visual / segmented".

**Depends on:** plan 01 Tasks 1 (Node harness), 4 (`collectorUserScript`, collector world) and 6 (`sameSite`).

## Global Constraints

- Everything in plan 01's Global Constraints applies.
- The layout script reads (`getBoundingClientRect`, `getComputedStyle`); it never scrolls, resizes or writes to the page.
- Coordinates are CSS pixels in page space (origin = top-left of the document, not of the viewport).
- First version: web pages in the browser only. For a local file or without a browser the tab says so (`Unavailable`), it does not guess a layout from the source.

## Review Focus

1. A very tall page (infinite scroll, 100,000 px): the drawing is scaled so its height never exceeds `kMaxWireframeHeight` (6000 logical px); it stays scrollable and tappable (Task 3 test `wireframeScale`).
2. More qualifying elements than the cap: the first 400 are drawn and the tab says how many were left out (Tasks 1 and 3).
3. A page without layout (blank document, zero-size body): `Unavailable` with `the page has no layout`, not an empty canvas (Task 2).
4. A result that arrives after the user navigated on is dropped (Task 2 test).
5. Fixed and sticky elements (cookie banners, headers) overlap content: drawn last with a dashed outline; a tap on the overlap picks the smallest box under the point (Task 3 test `blockAt`).

---

### Task 1: Measure the page's boxes

**Files:**
- Create: `lib/services/collectors/vsv_layout_js.dart`
- Modify: `lib/services/collectors/collector_world.dart` (append the script to `collectorUserScript`'s source)
- Test: `test/collectors/vsv_layout_js_test.dart`

**Interfaces:**
- Produces: `const String vsvLayoutJs` defining `window.__vsv_layout()`, which returns a JSON string:

```json
{"v": 1, "vw": 412, "vh": 823, "w": 412, "h": 5210, "total": 57,
 "blocks": [{"t": "header", "r": "banner", "i": "top", "c": "site-header dark",
             "x": 0, "y": 0, "w": 412, "h": 64, "d": 2, "n": 31,
             "k": "landmark", "s": "", "f": 1, "tx": ""}]}
```

  `vw`/`vh` viewport; `w`/`h` document size (`scrollWidth`/`scrollHeight` of `document.scrollingElement`); `total` = qualifying elements; `blocks` = the first 400 in document order. Per block: `t` tag, `r` `role` attribute, `i` id (≤ 60 chars), `c` first two class names (≤ 60 chars), `x y w h` rounded page coordinates, `d` depth below `body`, `n` descendant elements, `k` kind, `s` absolute source URL (`iframe`: `src`; `img`/`video`: `currentSrc || src`; no `data:`), `f` 1 when `position` is `fixed` or `sticky`, `tx` text (headings only, whitespace collapsed, ≤ 80 chars).
- Kinds, first match wins:

| kind | element |
|---|---|
| `frame` | `iframe` |
| `heading` | `h1`–`h6` |
| `landmark` | `header nav main article section aside footer form dialog`, or `role` in `banner navigation main complementary contentinfo search form region dialog` |
| `media` | `video`, `canvas`, or `img` with area ≥ 10,000 px² |
| `block` | any other element with area ≥ 15% of the viewport area, ≥ 20 descendants, depth ≤ 12 |

- Skipped: width or height below 1 px; `visibility: hidden`; entirely left of or above the document origin. At most the first 20,000 elements of `body` are looked at.
- On a document without `body` or with `w` or `h` of 0: `{"v": 1, "empty": true}`.

- [ ] **Step 1: Write the failing tests**

The test builds a fake DOM in a `before` string: elements are objects with `tagName`, `id`, `className`, `getAttribute`, `getBoundingClientRect`, `getElementsByTagName`, `parentNode`, `textContent`, `src`; `document.body.getElementsByTagName('*')` returns them; `getComputedStyle` returns `{position, visibility}` from the object; `window.scrollX/scrollY`, `innerWidth/innerHeight`.

```dart
test('landmarks, frames, headings and big blocks are measured', () async {
  final r = await layout(fakeDom); // header, h1, iframe, small div, big div (30 children), hidden nav
  if (r == null) return markTestSkipped('node not installed');
  expect(r['blocks'].map((b) => '${b['t']}:${b['k']}'),
      ['header:landmark', 'h1:heading', 'iframe:frame', 'div:block']);
  expect(r['blocks'][1]['tx'], 'Welcome to the shop');
  expect(r['blocks'][2]['s'], 'https://ads.test/slot');
  expect(r['total'], 4);
});
test('coordinates are page coordinates', () async {
  // window.scrollY = 500, an element whose rect.top is -100 → y == 400
});
test('fixed elements are flagged', () async { /* position: 'fixed' → f == 1 */ });
test('more than 400 qualifying elements are capped', () async {
  // 450 sections → blocks.length == 400, total == 450
});
test('a document without layout is empty', () async {
  // scrollHeight 0 → {'v': 1, 'empty': true}
});
```

`layout(String dom)` is a local helper on `runJs` (plan 04 Task 1; if that is not merged, add `runJs` to `test/support/collector_node.dart` here with the same signature: `Future<String?> runJs(String source)`).

- [ ] **Step 2: Run, see them fail, implement, run, commit**

Run: `flutter test test/collectors/vsv_layout_js_test.dart`
```bash
git commit -am "Collector: measure the page's landmarks, frames, media and large blocks"
```

---

### Task 2: `PageLayout` in the store

**Files:**
- Create: `lib/models/inspection/page_layout.dart`
- Create: `lib/services/collectors/layout_payload.dart`
- Modify: `lib/models/inspection/page_inspection.dart`, `lib/services/inspection_store.dart`
- Modify: `lib/services/html_service.dart` (`collectLayout`; call it where `_captureLiveScreenshot(gen)` is called after the browser settled)
- Test: `test/collectors/layout_payload_test.dart`, `test/services/inspection_store_test.dart`

**Interfaces:**
- Produces:

```dart
enum LayoutKind { landmark, frame, heading, media, block }

class LayoutBlock {
  final String tag, role, id, classes, src, text;
  final double x, y, width, height;
  final int depth, descendants;
  final LayoutKind kind;
  final bool fixed;
  const LayoutBlock({required ...});
  double get area => width * height;
}

class PageLayout {
  final double viewportWidth, viewportHeight, width, height;
  final int totalBlocks;
  final List<LayoutBlock> blocks;
  bool get truncated => totalBlocks > blocks.length;
  const PageLayout({required ...});
}

Observed<PageLayout> parseLayoutPayload(Object? raw, {required Uri pageUrl});
```

  `parseLayoutPayload`: a non-String → `Unavailable(unsupportedPlatform)`; unparsable → `Failed`; `empty: true` → `Unavailable(notApplicable, 'the page has no layout')`; a block with an unknown kind or non-numeric box is skipped; `s` is resolved against `pageUrl`.
- `PageInspection.layout`: `Observed<PageLayout>`, default `Unavailable(UnavailableReason.notApplicable, 'not measured yet')`, in `copyWith` and `empty`.
- `InspectionStore.applyLayout(int gen, Observed<PageLayout> layout)`: ignored for another generation.
- `Future<void> HtmlService.collectLayout()`: sets `Pending`, evaluates `window.__vsv_layout && window.__vsv_layout()` with `contentWorld: collectorWorld(defaultTargetPlatform)`, parses, applies; an exception becomes `Failed`. No controller → `Unavailable(notApplicable, 'needs the browser')`. A test seam like `_browserCollectOverride` (constructor parameter `BrowserCollect? layoutCollect`).

- [ ] **Step 1: Write the failing tests**

```dart
test('the payload of Task 1 parses', () {
  final l = (parseLayoutPayload(sample, pageUrl: Uri.parse('https://a.test/x'))
      as Present<PageLayout>).value;
  expect(l.height, 5210);
  expect(l.blocks.single.kind, LayoutKind.landmark);
  expect(l.blocks.single.fixed, isTrue);
  expect(l.truncated, isTrue); // total 57, one block
});
test('an empty document is unavailable with the reason', () {
  final o = parseLayoutPayload('{"v":1,"empty":true}', pageUrl: u);
  expect((o as Unavailable<PageLayout>).detail, 'the page has no layout');
});
test('bad blocks are skipped, bad payloads fail', () {
  // blocks: [{'k': 'weird'}, {'k': 'frame', 'x': 'a'}] → Present with no blocks
  // 'not json' → Failed; 42 → Unavailable(unsupportedPlatform)
});
test('a relative frame source is resolved', () { /* 's': '/embed' → https://a.test/embed */ });
// inspection_store_test.dart
test('a layout for an earlier navigation is dropped', () {
  // gen1 = beginUrl(a); beginUrl(b); applyLayout(gen1, Present(...)) → current.layout unchanged
});
```

- [ ] **Step 2: Run, see them fail, implement, run the suite, commit**

Run: `flutter analyze --no-pub && flutter test`
```bash
git commit -am "Store the measured page layout"
```

---

### Task 3: `deriveStructure` and the geometry helpers

**Files:**
- Create: `lib/services/derive/structure_view.dart`
- Test: `test/derive/structure_view_test.dart`

**Interfaces:**
- Consumes: `PageLayout`, `sameSite`, `externalServicesForUrl`.
- Produces:

```dart
enum BlockOwner { page, ownFrame, thirdParty, advertising, social }

class StructureBlock {
  final LayoutBlock block;
  final BlockOwner owner;
  final String label;      // 'header#top.site-header', 'iframe · ads.test', 'h2'
  final String? service;   // catalogue name when the source belongs to one
}

class OutlineItem { final int level; final String text; }

class StructureModel {
  final PageLayout layout;
  final List<StructureBlock> blocks;   // paint order: by area descending, fixed last
  final List<OutlineItem> headings;    // document order
  final List<String> landmarks;        // which of header, nav, main, footer exist
  final List<String> notes;
  final double thirdPartyShare;        // 0..1 of the page area under third-party frames
}

Observed<StructureModel> deriveStructure(PageInspection p);

const double kMaxWireframeHeight = 6000;
/// Scale from page pixels to logical pixels: fits [availableWidth], and
/// never lets the drawing exceed [kMaxWireframeHeight].
double wireframeScale(PageLayout l, double availableWidth);
/// The smallest block that contains the page point; null when none does.
StructureBlock? blockAt(StructureModel m, double pageX, double pageY);
/// 1-based line of the first `id="<id>"` or `id='<id>'` in [source]; null
/// when absent or when [id] is empty.
int? lineOfId(String source, String id);
```

- Owner: a `frame` or `media` block with a source: an entity from `externalServicesForUrl(src, pageUrl)` with category `advertising` → `advertising`, `social` → `social`; else host not `sameSite` with the page → `thirdParty`; a same-site `frame` → `ownFrame`; everything else `page`.
- `thirdPartyShare`: summed area of frames whose owner is not `page`/`ownFrame`, each clipped to the document box, divided by `width × height`, capped at 1.
- Notes, each only when true: `Only the first 400 of N blocks are drawn.`; `No main landmark.`; `N h1 headings (one is usual).` when N ≠ 1; `Heading levels skip from hA to hB.` (first skip only); `Third-party frames cover P% of the page.` when ≥ 5%.
- `deriveStructure` passes through the state of `p.layout` when it is not Present (`Pending`, `Failed`, `Unavailable`); for a `FileTarget`: `Unavailable(notApplicable, 'only for pages loaded in the browser')`.

- [ ] **Step 1: Write the failing tests**

```dart
test('frames are owned by who serves them', () {
  final m = present(deriveStructure(pageWith(url: 'https://shop.test/', blocks: [
    frame('https://googleads.g.doubleclick.net/slot', w: 300, h: 250),
    frame('https://widgets.shop.test/chat'),
    frame('https://maps.other.test/embed'),
    block('main', kind: LayoutKind.landmark),
  ])));
  expect(m.blocks.map((b) => b.owner).toSet(), {
    BlockOwner.advertising, BlockOwner.ownFrame, BlockOwner.thirdParty, BlockOwner.page});
  expect(m.blocks.firstWhere((b) => b.owner == BlockOwner.advertising).service, isNotNull);
});
test('third-party share of the page area', () {
  // page 1000×4000, one third-party frame 500×800 → 0.1; note 'Third-party frames cover 10% of the page.'
});
test('outline notes', () {
  // headings h1, h1, h2, h4, no main → notes contain
  // 'No main landmark.', '2 h1 headings (one is usual).', 'Heading levels skip from h2 to h4.'
});
test('wireframeScale', () {
  expect(wireframeScale(layout(w: 400, h: 2000), 400), 1.0);
  expect(wireframeScale(layout(w: 1200, h: 2400), 400), closeTo(1 / 3, 1e-9));
  expect(wireframeScale(layout(w: 400, h: 100000), 400), closeTo(0.06, 1e-9));
});
test('blockAt picks the smallest box under the point', () {
  // main 0,0,400,2000 ; article 0,100,400,600 ; fixed banner 0,0,400,60
  // (10, 30) → banner ; (10, 300) → article ; (10, 1500) → main ; (900, 10) → null
});
test('lineOfId', () {
  expect(lineOfId('<a>\n<div id="top">\n', 'top'), 2);
  expect(lineOfId("<p id='x'>", 'x'), 1);
  expect(lineOfId('<p id="xy">', 'x'), isNull);
  expect(lineOfId('<p>', ''), isNull);
});
test('a local file has no structure view', () {
  expect(deriveStructure(localFilePage), isA<Unavailable<StructureModel>>());
});
```

- [ ] **Step 2: Run, see them fail, implement, run, commit**

Run: `flutter test test/derive/structure_view_test.dart`
```bash
git commit -am "Derive the structure view: owners, outline, notes, geometry"
```

---

### Task 4: Structure tab

**Files:**
- Modify: `lib/models/app_tab.dart`: `structure(TabGroup.code, 'Structure', Icons.dashboard_outlined, 'structure')` before `domTree`; visible when `browser && isHtml`
- Create: `lib/widgets/structure_view.dart`, `lib/widgets/structure_painter.dart`
- Modify: `lib/screens/home_screen.dart` (page for the tab), `lib/services/html_service.dart` (getter `structureView`, cached on the identity of `store.current`)
- Modify: `lib/services/inspection_export_service.dart` (`analysis/structure.json`, wrapped by `unlessBlocked`)
- Modify: `README.md` and the About screen's Key Features (one line each)
- Test: `test/widgets/structure_data_test.dart`, `test/tab_functionality_test.dart`, `test/inspection_export_service_test.dart`

**Interfaces:**
- Consumes: `deriveStructure`, `wireframeScale`, `blockAt`, `lineOfId` (Task 3); `HtmlService.collectLayout` (Task 2); `HtmlService.revealSourceLine`.

Layout of the tab, top to bottom:
1. The notes, as a short list.
2. A `SegmentedButton`: `Owner` (default) | `Element`, and a refresh icon button (`collectLayout`).
3. A legend for the active colouring. Owner: Page, Own frame, Third party, Advertising, Social. Element: Landmark, Frame, Heading, Media, Block. Colours come from the theme's `ColorScheme` (no hard-coded hex); owner colours reuse the tones the Privacy tab uses for the same categories.
4. The wireframe: a `CustomPaint` of width = available width and height = `layout.height × scale`, inside the tab's vertical scroll. Blocks as filled rectangles with a 1 px outline, in `model.blocks` order; fixed blocks with a dashed outline; a horizontal dashed line at `viewportHeight × scale` labelled `first screen`; labels inside a block only when it is at least 60 × 16 logical px.
5. `Headings`: the outline as an indented list (indent = level), or `No headings.`
6. The `AnalysisDisclaimer`.

Tap on the wireframe: convert the local position to page coordinates (divide by scale), `blockAt`; show a bottom sheet with the label, `W × H px at (x, y)`, kind, owner, service or source host, descendant count, `fixed` when set, and a `Show in source` button when `lineOfId(currentSource, block.id)` is not null (calls `revealSourceLine`). The sheet's line lookup is done by a method on `HtmlService` (`int? sourceLineOfId(String id)`), not in the widget.

States: `Pending` → progress indicator with `Measuring the page…`; `Unavailable`/`Failed` → the reason via `unknownText` and a `Try again` button when a browser exists.

Export shape: `{'viewport': {w, h}, 'page': {w, h}, 'totalBlocks', 'thirdPartyShare', 'landmarks', 'notes', 'headings': [{level, text}], 'blocks': [{tag, role, id, classes, x, y, w, h, depth, descendants, kind, owner, service, src, fixed}]}`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the tab draws the wireframe and the outline', (tester) async {
  await pumpStructure(tester, pageWithLayout);
  expect(find.byType(CustomPaint), findsWidgets);
  expect(find.text('Owner'), findsOneWidget);
  expect(find.text('Welcome to the shop'), findsOneWidget); // h1 in the outline
  expect(find.textContaining('Third-party frames cover'), findsOneWidget);
});
testWidgets('a tap on a block opens its details', (tester) async {
  await pumpStructure(tester, pageWithLayout);
  await tester.tapAt(wireframeOrigin(tester) + const Offset(20, 20)); // inside header
  await tester.pumpAndSettle();
  expect(find.textContaining('header#top'), findsOneWidget);
});
testWidgets('without a browser the tab says why', (tester) async {
  await pumpStructure(tester, localFilePage);
  expect(find.textContaining('only for pages loaded in the browser'), findsOneWidget);
});
test('the export has the structure', () {
  // zip contains analysis/structure.json with 'blocks' and 'headings'
});
```

`pumpStructure` and `wireframeOrigin` are local helpers on `makeService` / `pumpWithProviders` from `test/fixtures/inspection/pump.dart`; give the wireframe a `Key('structure-wireframe')`.

- [ ] **Step 2: Run, see them fail, implement, run the suite**

Run: `flutter analyze --no-pub && flutter test`
Expected: PASS including the architecture test.

- [ ] **Step 3: Real check (macOS and one phone-sized simulator)**

Open a news site, wait until it settles, open Structure.
Expected: the wireframe shows header, main and footer in page proportions; ad frames are in the advertising colour; tapping a frame names its host; `Element` recolours by kind; the drawing scrolls and no label overflows its box at phone width.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Add Structure tab: segmented wireframe of the rendered page"
```

---

## Final gate

- [ ] `flutter analyze --no-pub && flutter test`: clean, all pass.
- [ ] When plan 02 is merged: add the summary rule `third-party-area` (low): `Third-party frames cover P% of the page` when the share is ≥ 20%, with a test.
- [ ] `CHANGELOG.md` entry.
