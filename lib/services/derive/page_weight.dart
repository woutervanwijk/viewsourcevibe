import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../probe_service.dart';

/// Totals of one resource type. A size is null when no resource of the type
/// reported one: never 0.
class WeightBucket {
  int count = 0;
  int? transfer;
  int? decoded;

  void addTransfer(int v) => transfer = (transfer ?? 0) + v;
  void addDecoded(int v) => decoded = (decoded ?? 0) + v;
}

/// The page weight derived from the browser's resources (plus the server's
/// document). The totals are the sum of the [breakdown] by construction.
class PageWeight {
  /// Keys: scripts, css, images, html, other.
  final Map<String, WeightBucket> breakdown;

  /// Sum of the breakdown; null when nothing reported a size.
  final int? transfer;
  final int? decoded;

  /// True when something is missing from the totals (a resource without a
  /// transfer size, a non-image without a decoded size, truncated resources):
  /// the totals are then a lower bound.
  final bool isPartial;

  /// Set when the main document's sizes come from the server body (the
  /// browser does not report them).
  final DataSource? documentSource;
  final double? snapshotTimeMs;

  const PageWeight({
    required this.breakdown,
    required this.transfer,
    required this.decoded,
    required this.isPartial,
    required this.documentSource,
    required this.snapshotTimeMs,
  });

  /// `estimated` when the totals are a lower bound, else `measured`.
  Provenance get provenance =>
      isPartial ? Provenance.estimated : Provenance.measured;

  /// Prefix for a displayed total: "≥ " when it is a lower bound.
  String get totalPrefix => isPartial ? '≥ ' : '';
}

/// Page weight from [p]; null unless the browser's resources are Present.
///
/// Images are judged by their transfer size: WebKit (iOS/macOS) reports the
/// decoded pixel buffer for them, so their decoded size is never added there
/// and its absence is not a gap.
PageWeight? derivePageWeight(PageInspection p) {
  final browser = p.browser;
  if (browser is! Present<BrowserSnapshot>) return null;
  final b = browser.value;
  final res = b.resources;
  if (res is! Present<List<ResourceEntry>>) return null;

  final pageUrl = b.url.toString();
  final buckets = {
    'scripts': WeightBucket(),
    'css': WeightBucket(),
    'images': WeightBucket(),
    'html': WeightBucket(),
    'other': WeightBucket(),
  };
  var partial = b.resourcesTruncated;

  for (final r in res.value) {
    final category = ProbeService.categorizeResource(r.url, pageUrl);
    final isImage = category == 'image' || r.type == 'img' || r.type == 'image';
    final bucket = buckets[switch (category) {
      'script' => 'scripts',
      'style' => 'css',
      'image' => 'images',
      'document' => 'html',
      _ => 'other',
    }]!;
    bucket.count++;

    final tx = r.transfer;
    if (tx is Present<int>) {
      bucket.addTransfer(tx.value);
    } else {
      partial = true;
    }

    final dec = r.decoded;
    if (dec is Present<int>) {
      if (!(isImage && b.platform.isWebKit)) bucket.addDecoded(dec.value);
    } else if (!isImage) {
      partial = true;
    }
  }

  DataSource? documentSource;
  final server = p.server;
  if (server is Present<ServerSnapshot>) {
    final body = server.value.body;
    if (body is Present<ServerBody>) {
      final html = buckets['html']!;
      html.count++;
      html.addTransfer(body.value.transferLength);
      html.addDecoded(body.value.byteLength);
      if (body.value.truncated) partial = true;
      documentSource = DataSource.server;
    }
  }

  int? sum(int? Function(WeightBucket) f) {
    final values = buckets.values.map(f).whereType<int>();
    return values.isEmpty ? null : values.fold<int>(0, (a, x) => a + x);
  }

  final snap = b.snapshotTimeMs;
  return PageWeight(
    breakdown: buckets,
    transfer: sum((x) => x.transfer),
    decoded: sum((x) => x.decoded),
    isPartial: partial,
    documentSource: documentSource,
    snapshotTimeMs: snap is Present<double> ? snap.value : null,
  );
}
