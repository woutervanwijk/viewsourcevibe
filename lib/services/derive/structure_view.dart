import 'dart:math' as math;

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/page_layout.dart';
import '../../utils/site.dart';
import '../detection/engine.dart';

enum BlockOwner { page, ownFrame, thirdParty, advertising, social }

class StructureBlock {
  final LayoutBlock block;
  final BlockOwner owner;

  /// 'header#top.site-header', 'iframe · ads.test', 'h2'.
  final String label;

  /// Catalogue name when the source belongs to one.
  final String? service;

  const StructureBlock(
      {required this.block,
      required this.owner,
      required this.label,
      this.service});
}

class OutlineItem {
  final int level;
  final String text;
  const OutlineItem(this.level, this.text);
}

class StructureModel {
  final PageLayout layout;

  /// Paint order: by area descending, fixed and sticky last.
  final List<StructureBlock> blocks;

  /// Document order.
  final List<OutlineItem> headings;

  /// Which of header, nav, main, footer exist.
  final List<String> landmarks;
  final List<String> notes;

  /// Which viewport the layout was measured at.
  final String measuredAt;

  /// 0..1 of the page area under third-party frames.
  final double thirdPartyShare;

  const StructureModel({
    required this.layout,
    required this.blocks,
    required this.headings,
    required this.landmarks,
    required this.notes,
    required this.measuredAt,
    required this.thirdPartyShare,
  });
}

const double kMaxWireframeHeight = 6000;

/// Scale from page pixels to logical pixels: fits [availableWidth], and
/// never lets the drawing exceed [kMaxWireframeHeight].
double wireframeScale(PageLayout l, double availableWidth) {
  if (l.width <= 0 || l.height <= 0) return 1;
  return math.min(availableWidth / l.width, kMaxWireframeHeight / l.height);
}

/// The smallest block that contains the page point; null when none does.
StructureBlock? blockAt(StructureModel m, double pageX, double pageY) {
  StructureBlock? best;
  for (final b in m.blocks) {
    final k = b.block;
    if (pageX < k.x || pageY < k.y) continue;
    if (pageX > k.x + k.width || pageY > k.y + k.height) continue;
    if (best == null || k.area <= best.block.area) best = b;
  }
  return best;
}

/// 1-based line of the first `id="<id>"` or `id='<id>'` in [source]; null
/// when absent or when [id] is empty.
int? lineOfId(String source, String id) {
  if (id.isEmpty) return null;
  final m = RegExp(
          '\\bid\\s*=\\s*(?:"${RegExp.escape(id)}"|\'${RegExp.escape(id)}\')')
      .firstMatch(source);
  if (m == null) return null;
  return '\n'.allMatches(source.substring(0, m.start)).length + 1;
}

const _notInBrowser = Unavailable<StructureModel>(
    UnavailableReason.notApplicable, 'only for pages loaded in the browser');

Observed<StructureModel> deriveStructure(PageInspection p) {
  if (p.target is FileTarget) return _notInBrowser;
  final layoutState = p.layout;
  switch (layoutState) {
    case Pending<PageLayout>(:final detail):
      return Pending(detail);
    case Failed<PageLayout>(:final error):
      return Failed(error);
    case Unavailable<PageLayout>(:final reason, :final detail):
      return Unavailable(reason, detail);
    case Present<PageLayout>(:final value, :final source):
      return Present(_derive(value, _pageUrl(p)), source: source);
  }
}

String _pageUrl(PageInspection p) {
  final t = p.target;
  if (t is UrlTarget) return t.url.toString();
  final b = p.browser;
  return b is Present<BrowserSnapshot> ? b.value.url.toString() : '';
}

const _landmarkNames = {
  'header': 'header',
  'banner': 'header',
  'nav': 'nav',
  'navigation': 'nav',
  'main': 'main',
  'footer': 'footer',
  'contentinfo': 'footer',
};

String _hostOf(String url) => Uri.tryParse(url)?.host ?? '';

String _labelOf(LayoutBlock b) {
  if (b.kind == LayoutKind.frame) {
    final host = _hostOf(b.src);
    return host.isEmpty ? b.tag : '${b.tag} · $host';
  }
  final firstClass = b.classes
      .split(RegExp(r'\s+'))
      .firstWhere((c) => c.isNotEmpty, orElse: () => '');
  return '${b.tag}${b.id.isEmpty ? '' : '#${b.id}'}'
      '${firstClass.isEmpty ? '' : '.$firstClass'}';
}

StructureBlock _classify(LayoutBlock b, String pageUrl) {
  var owner = BlockOwner.page;
  String? service;
  final hasSource =
      (b.kind == LayoutKind.frame || b.kind == LayoutKind.media) &&
          b.src.isNotEmpty;
  if (hasSource) {
    final entities = externalServicesForUrl(b.src, pageUrl);
    final ad =
        entities.where((e) => e.category == DetectionCategory.advertising);
    final social =
        entities.where((e) => e.category == DetectionCategory.social);
    final pageHost = _hostOf(pageUrl);
    final host = _hostOf(b.src);
    if (ad.isNotEmpty) {
      owner = BlockOwner.advertising;
      service = ad.first.name;
    } else if (social.isNotEmpty) {
      owner = BlockOwner.social;
      service = social.first.name;
    } else if (host.isNotEmpty && !sameSite(host, pageHost)) {
      owner = BlockOwner.thirdParty;
      if (entities.isNotEmpty) service = entities.first.name;
    } else if (b.kind == LayoutKind.frame) {
      owner = BlockOwner.ownFrame;
    }
  }
  return StructureBlock(
      block: b, owner: owner, label: _labelOf(b), service: service);
}

final _headingTag = RegExp(r'^h([1-6])$');

int _headingLevel(String tag) =>
    int.parse(_headingTag.firstMatch(tag)?.group(1) ?? '1');

String _n(double v) => v.round().toString();

StructureModel _derive(PageLayout l, String pageUrl) {
  final all = [for (final b in l.blocks) _classify(b, pageUrl)];

  final painted = [...all]..sort((a, b) {
      if (a.block.fixed != b.block.fixed) return a.block.fixed ? 1 : -1;
      return b.block.area.compareTo(a.block.area);
    });

  final headings = <OutlineItem>[
    for (final b in l.blocks)
      if (b.kind == LayoutKind.heading)
        OutlineItem(_headingLevel(b.tag), b.text),
  ];

  final found = <String>{
    for (final b in l.blocks)
      if (b.kind == LayoutKind.landmark)
        if ((_landmarkNames[b.tag] ?? _landmarkNames[b.role]) case final name?)
          name,
  };
  final landmarks = [
    for (final n in const ['header', 'nav', 'main', 'footer'])
      if (found.contains(n)) n
  ];

  var thirdPartyArea = 0.0;
  for (final s in all) {
    final b = s.block;
    if (b.kind != LayoutKind.frame ||
        s.owner == BlockOwner.page ||
        s.owner == BlockOwner.ownFrame) {
      continue;
    }
    final w = math.min(b.x + b.width, l.width) - math.max(b.x, 0);
    final h = math.min(b.y + b.height, l.height) - math.max(b.y, 0);
    if (w > 0 && h > 0) thirdPartyArea += w * h;
  }
  final pageArea = l.width * l.height;
  final share = pageArea <= 0 ? 0.0 : math.min(1.0, thirdPartyArea / pageArea);

  final notes = <String>[
    if (l.truncated)
      'Only the first ${l.blocks.length} of ${l.totalBlocks} blocks are drawn.',
    if (l.scanCapped)
      'Only the first 20000 elements were measured; landmark and heading '
          'notes may be incomplete.',
    if (l.totalBlocks == 0 && l.blocks.isEmpty)
      'Nothing on this page is large or marked up enough to draw: no '
          'landmarks, headings, frames, media or large blocks.',
    if (!landmarks.contains('main')) 'No main landmark.',
  ];
  final h1s = headings.where((h) => h.level == 1).length;
  if (h1s != 1) notes.add('$h1s h1 headings (one is usual).');
  for (var i = 1; i < headings.length; i++) {
    final from = headings[i - 1].level, to = headings[i].level;
    if (to > from + 1) {
      notes.add('Heading levels skip from h$from to h$to.');
      break;
    }
  }
  if (share >= 0.05) {
    notes
        .add('Third-party frames cover ${(share * 100).round()}% of the page.');
  }

  return StructureModel(
    layout: l,
    blocks: painted,
    headings: headings,
    landmarks: landmarks,
    notes: notes,
    measuredAt:
        'Measured at ${_n(l.viewportWidth)}\u00d7${_n(l.viewportHeight)}',
    thirdPartyShare: share,
  );
}
