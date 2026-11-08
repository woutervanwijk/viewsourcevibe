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

  /// Part of [transfer] that is the app's own estimate (null: none).
  int? estimatedTransfer;

  /// Resources of this type that have no transfer size at all.
  int missingCount = 0;

  /// Non-image resources of this type without a decoded size (an image's
  /// decoded size is never expected, see [derivePageWeight]).
  int decodedMissingCount = 0;

  /// Transfer prefix: "≥ " when a resource has no transfer size, then "≈ "
  /// when part of it is the app's own estimate.
  String get transferPrefix =>
      '${missingCount > 0 ? '≥ ' : ''}${estimatedTransfer != null ? '≈ ' : ''}';

  /// Decoded prefix: "≥ " when a resource lacks its decoded size. Decoded is
  /// never estimated. (Truncation is a page-level fact, see [PageWeight].)
  String get decodedPrefix => decodedMissingCount > 0 ? '≥ ' : '';

  void addTransfer(int v) => transfer = (transfer ?? 0) + v;
  void addEstimate(int v) {
    addTransfer(v);
    estimatedTransfer = (estimatedTransfer ?? 0) + v;
  }

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

  /// [transfer] split in what the browser measured and what the app's own
  /// lookups estimated (both null when nothing contributed), and the number
  /// of resources without any transfer size.
  final int? measuredTransfer;
  final int? estimatedTransfer;
  final int missingCount;

  /// The transfer total is a lower bound: a resource has no transfer size
  /// (and no estimate), or the browser's resources / the server body were
  /// truncated.
  final bool transferLowerBound;

  /// The transfer total includes the app's own estimates.
  final bool transferEstimated;

  /// The decoded total is a lower bound: a non-image resource has no decoded
  /// size, or resources were truncated. Decoded is never estimated.
  final bool decodedLowerBound;

  /// Set when the main document's sizes come from the server body (the
  /// browser does not report them).
  final DataSource? documentSource;
  final double? snapshotTimeMs;

  const PageWeight({
    required this.breakdown,
    required this.transfer,
    required this.decoded,
    this.measuredTransfer,
    this.estimatedTransfer,
    this.missingCount = 0,
    required this.transferLowerBound,
    required this.transferEstimated,
    required this.decodedLowerBound,
    required this.documentSource,
    required this.snapshotTimeMs,
  });

  /// `estimated` when a total is a lower bound or includes an estimate, else
  /// `measured`.
  Provenance get provenance =>
      transferLowerBound || transferEstimated || decodedLowerBound
          ? Provenance.estimated
          : Provenance.measured;

  /// Prefix of the transfer total: "≥ " when it is a lower bound, then "≈ "
  /// when it includes an own estimate; both give "≥ ≈ " (at least roughly).
  String get transferPrefix =>
      '${transferLowerBound ? '≥ ' : ''}${transferEstimated ? '≈ ' : ''}';

  /// Prefix of the decoded total: "≥ " when it is a lower bound. Never "≈".
  String get decodedPrefix => decodedLowerBound ? '≥ ' : '';
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
  var transferGap = b.resourcesTruncated;
  var decodedGap = b.resourcesTruncated;
  int? measured;
  var missing = 0;

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
      measured = (measured ?? 0) + tx.value;
    } else {
      final cached = tx is Unavailable<int> &&
          tx.reason == UnavailableReason.servedFromCache;
      final est = cached ? null : p.resourceEstimates[r.url];
      if (est is Present<int>) {
        bucket.addEstimate(est.value);
      } else {
        bucket.missingCount++;
        missing++;
        transferGap = true;
      }
    }

    final dec = r.decoded;
    if (dec is Present<int>) {
      if (!(isImage && b.platform.isWebKit)) bucket.addDecoded(dec.value);
    } else if (!isImage) {
      // Decoded is never estimated: an estimated resource still lacks it.
      bucket.decodedMissingCount++;
      decodedGap = true;
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
      measured = (measured ?? 0) + body.value.transferLength;
      html.addDecoded(body.value.byteLength);
      if (body.value.truncated) {
        transferGap = true;
        decodedGap = true;
      }
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
    measuredTransfer: measured,
    estimatedTransfer: sum((x) => x.estimatedTransfer),
    missingCount: missing,
    transferLowerBound: transferGap,
    transferEstimated: sum((x) => x.estimatedTransfer) != null,
    decodedLowerBound: decodedGap,
    documentSource: documentSource,
    snapshotTimeMs: snap is Present<double> ? snap.value : null,
  );
}
