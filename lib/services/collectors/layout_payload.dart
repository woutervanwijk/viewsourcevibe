import 'dart:convert';

import '../../models/inspection/observed.dart';
import '../../models/inspection/page_layout.dart';

const _noLayout = Unavailable<PageLayout>(
    UnavailableReason.notApplicable, 'the page has no layout');

/// Parses the JSON string returned by `__vsv_layout()`. A non-String result
/// is [Unavailable]; an unparsable one [Failed]; a page without layout
/// (`empty`, or no boxes at all) is [Unavailable] with a reason.
Observed<PageLayout> parseLayoutPayload(Object? raw, {required Uri pageUrl}) {
  if (raw is! String) {
    return Unavailable(UnavailableReason.unsupportedPlatform,
        'evaluateJavascript returned ${raw == null ? 'null' : raw.runtimeType}, not a String');
  }
  try {
    final m = jsonDecode(raw);
    if (m is! Map) return const Failed('layout payload is not an object');
    if (m['empty'] == true) return _noLayout;
    final blocks = <LayoutBlock>[];
    final list = m['blocks'];
    if (list is List) {
      for (final b in list) {
        final block = b is Map ? _block(b, pageUrl) : null;
        if (block != null) blocks.add(block);
      }
    }
    final total = _int(m['total']) ?? blocks.length;
    final width = _num(m['w']), height = _num(m['h']);
    if (width == null || height == null) {
      return const Failed('layout payload has no document size');
    }
    if (total == 0 && blocks.isEmpty) return _noLayout;
    return Present(
        PageLayout(
          viewportWidth: _num(m['vw']) ?? 0,
          viewportHeight: _num(m['vh']) ?? 0,
          width: width,
          height: height,
          totalBlocks: total,
          blocks: blocks,
        ),
        source: DataSource.browser);
  } catch (e) {
    return Failed('$e');
  }
}

double? _num(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;

String _str(Object? v) => v is String ? v : '';

LayoutBlock? _block(Map b, Uri pageUrl) {
  final kind = switch (b['k']) {
    'landmark' => LayoutKind.landmark,
    'frame' => LayoutKind.frame,
    'heading' => LayoutKind.heading,
    'media' => LayoutKind.media,
    'block' => LayoutKind.block,
    _ => null,
  };
  final x = _num(b['x']), y = _num(b['y']);
  final w = _num(b['w']), h = _num(b['h']);
  if (kind == null || x == null || y == null || w == null || h == null) {
    return null;
  }
  var src = _str(b['s']);
  if (src.isNotEmpty) {
    try {
      src = pageUrl.resolve(src).toString();
    } catch (_) {}
  }
  return LayoutBlock(
    tag: _str(b['t']),
    role: _str(b['r']),
    id: _str(b['i']),
    classes: _str(b['c']),
    src: src,
    text: _str(b['tx']),
    x: x,
    y: y,
    width: w,
    height: h,
    depth: _int(b['d']) ?? 0,
    descendants: _int(b['n']) ?? 0,
    kind: kind,
    fixed: b['f'] == 1 || b['f'] == true,
  );
}
