import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/derive/structure_view.dart';

import '../fixtures/inspection/local_file.dart';

LayoutBlock block(
  String tag, {
  LayoutKind kind = LayoutKind.block,
  String role = '',
  String id = '',
  String classes = '',
  String src = '',
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
  bool fixed = false,
}) =>
    LayoutBlock(
      tag: tag,
      role: role,
      id: id,
      classes: classes,
      src: src,
      text: '',
      x: x,
      y: y,
      width: w,
      height: h,
      depth: 1,
      descendants: 0,
      kind: kind,
      fixed: fixed,
    );

LayoutBlock frame(String src, {double w = 100, double h = 100}) =>
    block('iframe', kind: LayoutKind.frame, src: src, w: w, h: h);

LayoutBlock heading(String tag) => block(tag, kind: LayoutKind.heading, h: 20);

PageLayout layout(
        {double w = 1000,
        double h = 4000,
        List<LayoutBlock> blocks = const [],
        int? total}) =>
    PageLayout(
        viewportWidth: w,
        viewportHeight: 800,
        width: w,
        height: h,
        totalBlocks: total ?? blocks.length,
        blocks: blocks);

PageInspection pageWith({
  String url = 'https://shop.test/',
  List<LayoutBlock> blocks = const [],
  double w = 1000,
  double h = 4000,
  int? total,
}) =>
    PageInspection(
      generation: 1,
      target: UrlTarget(Uri.parse(url)),
      server: const Unavailable(UnavailableReason.notApplicable),
      browser: const Unavailable(UnavailableReason.notApplicable),
      file: const Unavailable(UnavailableReason.notApplicable),
      layout: Present(layout(w: w, h: h, blocks: blocks, total: total),
          source: DataSource.browser),
    );

StructureModel present(Observed<StructureModel> o) {
  expect(o, isA<Present<StructureModel>>());
  return (o as Present<StructureModel>).value;
}

void main() {
  test('frames are owned by who serves them', () {
    final m = present(deriveStructure(pageWith(blocks: [
      frame('https://googleads.g.doubleclick.net/slot', w: 300, h: 250),
      frame('https://widgets.shop.test/chat'),
      frame('https://maps.other.test/embed'),
      block('main', kind: LayoutKind.landmark),
    ])));
    expect(m.blocks.map((b) => b.owner).toSet(), {
      BlockOwner.advertising,
      BlockOwner.ownFrame,
      BlockOwner.thirdParty,
      BlockOwner.page
    });
    expect(
        m.blocks.firstWhere((b) => b.owner == BlockOwner.advertising).service,
        isNotNull);
  });

  test('labels', () {
    final m = present(deriveStructure(pageWith(blocks: [
      block('header',
          kind: LayoutKind.landmark, id: 'top', classes: 'site-header dark'),
      frame('https://ads.other.test/x'),
      heading('h2'),
    ])));
    final labels = m.blocks.map((b) => b.label).toSet();
    expect(labels, containsAll(['header#top.site-header', 'h2']));
    expect(labels.any((l) => l == 'iframe · ads.other.test'), isTrue);
  });

  test('third-party share of the page area', () {
    final m = present(deriveStructure(pageWith(blocks: [
      frame('https://maps.other.test/embed', w: 500, h: 800),
      block('main', kind: LayoutKind.landmark),
    ])));
    expect(m.thirdPartyShare, closeTo(0.1, 1e-9));
    expect(m.notes, contains('Third-party frames cover 10% of the page.'));
  });

  test('outline notes', () {
    final m = present(deriveStructure(pageWith(blocks: [
      heading('h1'),
      heading('h1'),
      heading('h2'),
      heading('h4'),
    ])));
    expect(
        m.notes,
        containsAll([
          'No main landmark.',
          '2 h1 headings (one is usual).',
          'Heading levels skip from h2 to h4.'
        ]));
    expect(m.headings.map((h) => h.level), [1, 1, 2, 4]);
    expect(m.landmarks, isEmpty);
  });

  test('truncation note and landmarks', () {
    final m = present(deriveStructure(pageWith(total: 500, blocks: [
      block('main', kind: LayoutKind.landmark),
      block('div', kind: LayoutKind.landmark, role: 'navigation'),
      heading('h1'),
    ])));
    expect(m.notes, contains('Only the first 3 of 500 blocks are drawn.'));
    expect(m.notes, isNot(contains('No main landmark.')));
    expect(m.landmarks, ['nav', 'main']);
  });

  test('paint order: area descending, fixed last', () {
    final m = present(deriveStructure(pageWith(blocks: [
      block('div', w: 10, h: 10),
      block('div', w: 500, h: 500),
      block('div', w: 900, h: 900, fixed: true),
    ])));
    expect(m.blocks.map((b) => b.block.area), [250000, 100, 810000]);
  });

  test('wireframeScale: page width, capped at 1000', () {
    expect(wireframeScale(layout(w: 400, h: 2000)), 1.0);
    expect(wireframeScale(layout(w: 1000, h: 2000)), 1.0);
    expect(wireframeScale(layout(w: 1200, h: 2400)), closeTo(1000 / 1200, 1e-9));
    // A very tall page no longer shrinks the drawing below page width.
    expect(wireframeScale(layout(w: 400, h: 100000)), 1.0);
  });

  test('occurrenceOfBlock counts same-signature blocks in document order', () {
    final blocks = [
      block('p', classes: 'a'),
      block('div'),
      block('p', classes: 'a'),
      block('p', classes: 'b'),
      block('p', classes: 'a', id: 'x'),
    ];
    expect(occurrenceOfBlock(blocks, blocks[0]), 0);
    expect(occurrenceOfBlock(blocks, blocks[2]), 1);
    expect(occurrenceOfBlock(blocks, blocks[3]), 0); // different classes
    expect(occurrenceOfBlock(blocks, blocks[4]), 0); // different id
    expect(occurrenceOfBlock(blocks, block('p', classes: 'a')), 0);
  });

  test('lineOfSignature picks the occurrence-th matching opening tag', () {
    const src = '<html>\n<body>\n<p class="a">one</p>\n<p id="x" class="a">two</p>'
        '\n<p class="b">three</p>\n</body>\n</html>';
    expect(lineOfSignature(src, tag: 'p', classes: 'a', occurrence: 0), 3);
    expect(lineOfSignature(src, tag: 'p', classes: 'a', occurrence: 1), 4);
    expect(lineOfSignature(src, tag: 'p', id: 'x', occurrence: 0), 4);
    expect(lineOfSignature(src, tag: 'p', classes: 'b', occurrence: 0), 5);
    expect(lineOfSignature(src, tag: 'p', occurrence: 2), 5);
    expect(lineOfSignature(src, tag: 'p', id: 'nope', occurrence: 0), isNull);
    expect(lineOfSignature(src, tag: 'table', occurrence: 0), isNull);
    // Class attribute with single quotes also matches.
    expect(lineOfSignature("<p class='a'>z</p>", tag: 'p', classes: 'a'), 1);
  });

  test('blockAt picks the smallest box under the point', () {
    final m = present(deriveStructure(pageWith(w: 400, h: 2000, blocks: [
      block('main', kind: LayoutKind.landmark, w: 400, h: 2000),
      block('article', y: 100, w: 400, h: 600),
      block('div', w: 400, h: 60, fixed: true),
    ])));
    expect(blockAt(m, 10, 30)?.block.tag, 'div');
    expect(blockAt(m, 10, 300)?.block.tag, 'article');
    expect(blockAt(m, 10, 1500)?.block.tag, 'main');
    expect(blockAt(m, 900, 10), isNull);
  });

  test('lineOfId', () {
    expect(lineOfId('<a>\n<div id="top">\n', 'top'), 2);
    expect(lineOfId("<p id='x'>", 'x'), 1);
    expect(lineOfId('<p id="xy">', 'x'), isNull);
    expect(lineOfId('<p>', ''), isNull);
  });

  test('a heading tag that is not h1..h6 does not throw', () {
    final m = present(deriveStructure(pageWith(blocks: [
      block('', kind: LayoutKind.heading),
      heading('h2'),
    ])));
    expect(m.headings.map((h) => h.level), [1, 2]);
  });

  test('the measuring viewport is stated', () {
    final m = present(deriveStructure(pageWith(w: 390)));
    expect(m.measuredAt, 'Measured at 390\u00d7800');
  });

  test('a page with nothing to draw says so', () {
    final m = present(deriveStructure(pageWith()));
    expect(
        m.notes,
        contains('Nothing on this page is large or marked up enough to draw: '
            'no landmarks, headings, frames, media or large blocks.'));
    expect(present(deriveStructure(pageWith(blocks: [heading('h1')]))).notes
        .join(), isNot(contains('Nothing on this page')));
  });

  test('a capped scan is noted', () {
    final p = pageWith(blocks: [heading('h1')]);
    final l = (p.layout as Present<PageLayout>).value;
    final capped = p.copyWith(
        layout: Present(
            PageLayout(
                viewportWidth: l.viewportWidth,
                viewportHeight: l.viewportHeight,
                width: l.width,
                height: l.height,
                totalBlocks: l.totalBlocks,
                blocks: l.blocks,
                scanCapped: true),
            source: DataSource.browser));
    expect(present(deriveStructure(capped)).notes, contains(
        'Only the first 20000 elements were measured; landmark and '
        'heading notes may be incomplete.'));
    expect(present(deriveStructure(p)).notes.join(),
        isNot(contains('20000')));
  });

  test('a local file has no structure view', () {
    expect(deriveStructure(localFile()), isA<Unavailable<StructureModel>>());
  });

  test('other layout states pass through', () {
    final p = pageWith().copyWith(layout: const Pending<PageLayout>());
    expect(deriveStructure(p), isA<Pending<StructureModel>>());
  });
}
