import 'dart:typed_data';

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../detection/engine.dart';
import 'page_weight.dart';

/// "12 KB" style size; the same rounding as the rest of the app.
String _kb(int bytes) {
  final kb = (bytes / 1024).ceil();
  final digits = kb.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out KB';
}

/// A size pair as text: "12 KB (↓ 4 KB)", "↓ 4 KB" when only the transfer is
/// known, null when neither is. A missing size is never "0 KB".
///
/// Each number takes its own prefix ("≥ ", "≈ "), so a lower bound on one
/// is never read as a statement about the other. When both are equal and
/// carry the same prefix they show as one.
String? formatSizePair(
    {int? decoded,
    int? transfer,
    String decodedPrefix = '',
    String transferPrefix = ''}) {
  if (decoded == null && transfer == null) return null;
  if (decoded == null) return '↓ $transferPrefix${_kb(transfer!)}';
  if (transfer != null &&
      (transfer != decoded || transferPrefix != decodedPrefix)) {
    return '$decodedPrefix${_kb(decoded)} (↓ $transferPrefix${_kb(transfer)})';
  }
  return '$decodedPrefix${_kb(decoded)}';
}

/// The Page size tab's size text: the download (transfer) size only, the
/// way Lighthouse's total byte weight counts a page ("2,500 KB"). Null when
/// unknown; never "0 KB".
String? formatDownloadSize(int? transfer, {String prefix = ''}) =>
    transfer == null ? null : '$prefix${_kb(transfer)}';

/// Lighthouse's "Avoid enormous network payloads" thresholds (KiB): up to
/// 2,667 passes, up to 4,000 needs improvement, above is poor.
const kLighthouseGoodKib = 2667;
const kLighthousePoorKib = 4000;

/// The Lighthouse verdict on the download total, or null when it is unknown.
/// A lower bound that is still under a threshold only says "at least".
String? lighthouseVerdict(PageWeight w, {String? basis}) {
  final t = w.transfer;
  if (t == null) return null;
  final kib = t / 1024;
  final verdict = kib <= kLighthouseGoodKib
      ? 'good (≤ 2,667 KB)'
      : kib <= kLighthousePoorKib
          ? 'needs improvement (≤ 4,000 KB)'
          : 'poor (> 4,000 KB)';
  final caveats = [
    if (w.transferLowerBound && kib <= kLighthousePoorKib)
      'the real total may be higher',
    if (w.transferEstimated) 'includes estimates',
  ];
  return 'Lighthouse${basis == null ? '' : ' ($basis)'}: $verdict'
      '${caveats.isEmpty ? '' : '; ${caveats.join(', ')}'}';
}

/// One loaded file. [size] is what the list is sorted and shared by: the
/// download (transfer) size, as Lighthouse sorts. Null = unknown, see
/// [sizeNote].
class PageSizeRow {
  final String url;

  /// script, style, image, document or other.
  final String type;
  final bool isPage;

  /// An audio/video file: no thumbnail can be shown for it.
  final bool isAudioVideo;
  final List<Entity> services;
  final int? size;

  /// Why the size is unknown (null when it is known).
  final String? sizeNote;

  /// The transfer size is the app's own estimate, not the browser's.
  final bool estimated;

  /// Served from the browser cache: the download size is that of a fresh
  /// load (the encoded body).
  final bool fromCache;

  /// Loaded by or inside a cross-origin iframe (ads, embeds).
  final bool thirdPartyFrame;

  const PageSizeRow({
    required this.url,
    required this.type,
    required this.isPage,
    required this.isAudioVideo,
    required this.services,
    required this.size,
    required this.sizeNote,
    this.estimated = false,
    this.fromCache = false,
    this.thirdPartyFrame = false,
  });

  /// "4 KB", "≈ 4 KB" (own estimate) or "size unknown (reason)".
  String get sizeLabel {
    final text = formatDownloadSize(size, prefix: estimated ? '≈ ' : '') ??
        'size unknown${sizeNote == null ? '' : ' ($sizeNote)'}';
    return fromCache ? '$text · cached' : text;
  }
}

class PageSizeModel {
  final PageWeight weight;
  final List<PageSizeRow> rows;

  /// Rows without any size.
  final int rowsWithoutSize;

  /// Explains what is missing from the totals; null when nothing is.
  final String? missingNote;

  /// Resources whose size is the app's own estimate.
  final int estimatedCount;

  /// Says that and how many sizes are estimates; null when none.
  final String? estimateNote;

  /// Images declared in the page's DOM that this load never fetched (lazy
  /// images, no scroll in the embedded view), now listed as rows.
  final int declaredCount;

  /// Says how many declared images were not loaded and how they are counted;
  /// null when none.
  final String? declaredNote;

  /// Lighthouse's verdict on the download total; null when it is unknown.
  final String? lighthouseNote;

  /// Says how cache hits are counted; null when there are none.
  final String? cacheNote;

  /// The live load may still add resources (the network is not quiet yet).
  final bool stillCollecting;

  /// Set when this load and the fresh load differ a lot (2× or more): says
  /// what usually causes that. Null otherwise.
  final String? differenceNote;

  /// Thumbnails of what this load and the fresh load showed.
  final Observed<Uint8List> liveScreenshot;
  final Observed<Uint8List> freshScreenshot;

  /// The fresh (Lighthouse-like) load: not measured, Pending, Failed or its
  /// own model (whose [fresh] is not measured).
  final Observed<PageSizeModel> fresh;

  const PageSizeModel({
    required this.weight,
    required this.rows,
    required this.rowsWithoutSize,
    required this.missingNote,
    this.estimatedCount = 0,
    this.estimateNote,
    this.declaredCount = 0,
    this.declaredNote,
    this.lighthouseNote,
    this.cacheNote,
    this.stillCollecting = false,
    this.fresh = kFreshNotMeasured,
    this.differenceNote,
    this.liveScreenshot = kNoScreenshot,
    this.freshScreenshot = kNoScreenshot,
  });

  PageSizeModel _with(
          {required Observed<PageSizeModel> fresh,
          required bool stillCollecting,
          required String? lighthouseNote,
          required String? differenceNote,
          required Observed<Uint8List> liveScreenshot,
          required Observed<Uint8List> freshScreenshot}) =>
      PageSizeModel(
        weight: weight,
        rows: rows,
        rowsWithoutSize: rowsWithoutSize,
        missingNote: missingNote,
        estimatedCount: estimatedCount,
        estimateNote: estimateNote,
        declaredCount: declaredCount,
        declaredNote: declaredNote,
        lighthouseNote: lighthouseNote,
        cacheNote: cacheNote,
        stillCollecting: stillCollecting,
        fresh: fresh,
        differenceNote: differenceNote,
        liveScreenshot: liveScreenshot,
        freshScreenshot: freshScreenshot,
      );

  /// Sum of the known row sizes (the share bars are relative to it).
  int get knownRowTotal => rows.fold<int>(0, (a, r) => a + (r.size ?? 0));
}

final _audioVideoPath =
    RegExp(r'\.(mp4|webm|mov|m4v|ogv|mp3|ogg|wav|m4a|aac)$');

String _normalizeUrl(String url) {
  final noFragment = url.split('#').first;
  return noFragment.endsWith('/')
      ? noFragment.substring(0, noFragment.length - 1)
      : noFragment;
}

/// Short reason why a size is not known ("blocked by the platform", ...).
String sizeReasonWord(Observed<int> o) => switch (o) {
      Unavailable<int>(reason: final r, detail: final d) => switch (r) {
          // "cross-origin" only when the collector said so.
          UnavailableReason.blockedByPlatform ||
          UnavailableReason.blockedBySite ||
          UnavailableReason.notExposedToPage when d.contains('cross-origin') =>
            'cross-origin',
          UnavailableReason.notReportedByPlatform
              when d.contains('collector buffer was full') =>
            'not collected (the collector buffer was full)',
          UnavailableReason.notReportedByPlatform
              when d.contains('memory cache') =>
            'shown, but served from the memory cache',
          UnavailableReason.blockedByPlatform => 'blocked by the platform',
          UnavailableReason.blockedBySite => 'blocked by the site',
          UnavailableReason.notExposedToPage => 'not exposed to the page',
          UnavailableReason.servedFromCache => 'served from cache',
          _ => 'not reported by the platform',
        },
      Failed<int>() => 'failed',
      _ => 'not reported',
    };

/// Ratio from which the two loads count as very different.
const kLoadDifferenceRatio = 2.0;

/// A sentence on why [live] and [fresh] differ, when one is at least
/// [kLoadDifferenceRatio] times the other; null otherwise or when a total
/// is unknown.
String? loadDifferenceNote(PageWeight live, PageWeight fresh) {
  final a = live.transfer, b = fresh.transfer;
  if (a == null || b == null || a == 0 || b == 0) return null;
  final ratio = a > b ? a / b : b / a;
  if (ratio < kLoadDifferenceRatio) return null;
  return 'The two loads differ a lot (${_kb(a)} vs ${_kb(b)}). That can be '
      'a cookie or consent wall, a paywall or a login page (the fresh load '
      'starts without your cookies), or ads and content that vary per load';
}

/// [PageSizeModel.fresh] before the user asked for a fresh load.
const kFreshNotMeasured =
    Unavailable<PageSizeModel>(UnavailableReason.notApplicable, 'not measured');

/// The Page size tab's data: the live load, plus the fresh (Lighthouse-like)
/// load when one was measured. Not Present when the browser has not (yet)
/// reported resources: the state says why (never an empty page).
Observed<PageSizeModel> derivePageSize(PageInspection p) {
  final live = _loadModel(p.browser, p.server, p.resourceEstimates,
      declaredMedia: p.declaredMedia);
  if (live is! Present<PageSizeModel>) return live;
  final fresh = _loadModel(p.freshLoad, p.server, p.freshEstimates,
      declaredMedia: p.declaredMedia);
  final note = fresh is Present<PageSizeModel>
      ? lighthouseVerdict(fresh.value.weight, basis: 'fresh load')
      : lighthouseVerdict(live.value.weight, basis: 'this load');
  return Present(
    live.value._with(
        fresh: fresh,
        stillCollecting: !p.browserSettled,
        lighthouseNote: note,
        differenceNote: fresh is Present<PageSizeModel>
            ? loadDifferenceNote(live.value.weight, fresh.value.weight)
            : null,
        liveScreenshot: p.liveScreenshot,
        freshScreenshot: p.freshScreenshot),
    source: live.source,
    provenance: live.provenance,
  );
}

Observed<PageSizeModel> _loadModel(
    Observed<BrowserSnapshot> browser, Observed<ServerSnapshot> server,
    Map<String, Observed<int>> estimates,
    {List<String> declaredMedia = const []}) {
  switch (browser) {
    case Pending<BrowserSnapshot>():
      return const Pending();
    case Failed<BrowserSnapshot>(:final error):
      return Failed(error);
    case Unavailable<BrowserSnapshot>(:final reason, :final detail):
      return Unavailable(reason, detail);
    case Present<BrowserSnapshot>(value: final b):
      final res = b.resources;
      switch (res) {
        case Pending<List<ResourceEntry>>():
          return const Pending();
        case Failed<List<ResourceEntry>>(:final error):
          return Failed(error);
        case Unavailable<List<ResourceEntry>>(:final reason, :final detail):
          return Unavailable(reason, detail);
        case Present<List<ResourceEntry>>(value: final entries):
          final weight = derivePageWeightOf(b,
              server: server,
              estimates: estimates,
              declaredMedia: declaredMedia)!;
          final pageUrl = b.url.toString();
          final page = _normalizeUrl(pageUrl);
          final byUrl = <String, PageSizeRow>{};
          final reasons = <String>{};
          for (final r in entries) {
            final url = r.url;
            if (url.isEmpty || url.startsWith('data:')) continue;
            final isPage = page.isNotEmpty && _normalizeUrl(url) == page;
            final type = isPage ? 'document' : resourceCategory(r, pageUrl);
            final measuredTx = r.transfer is Present<int>
                ? (r.transfer as Present<int>).value
                : null;
            final cached = r.fromCache;
            final estimate = measuredTx != null ? null : estimates[url];
            final estimatedTx =
                estimate is Present<int> ? estimate.value : null;
            // The download size only (Lighthouse); decoded is not shown.
            final size = measuredTx ?? estimatedTx;
            String? note;
            if (size == null) {
              note = switch (estimate) {
                Failed<int>() => 'size lookup failed',
                Unavailable<int>() => 'the server reported no size',
                _ => sizeReasonWord(r.transfer),
              };
              reasons.add(note);
            }
            final row = PageSizeRow(
              url: url,
              type: type,
              isPage: isPage,
              isAudioVideo: _audioVideoPath
                  .hasMatch(Uri.tryParse(url)?.path.toLowerCase() ?? ''),
              services: externalServicesForUrl(url, pageUrl),
              size: size,
              sizeNote: note,
              estimated: estimatedTx != null,
              fromCache: cached,
              thirdPartyFrame: isThirdPartyFrame(r, b.url),
            );
            final old = byUrl[url];
            if (old == null || (row.size ?? -1) > (old.size ?? -1)) {
              byUrl[url] = row;
            }
          }
          // Images declared in the DOM that this load never fetched (lazy
          // images; the embedded browser does not scroll): listed anyway, at
          // the app's own estimated size when the lookup succeeded.
          var declared = 0;
          for (final u in unfetchedDeclaredMedia(byUrl.keys, declaredMedia)) {
            final estimate = estimates[u];
            final estimatedTx =
                estimate is Present<int> ? estimate.value : null;
            byUrl[u] = PageSizeRow(
              url: u,
              type: 'image',
              isPage: false,
              isAudioVideo: _audioVideoPath
                  .hasMatch(Uri.tryParse(u)?.path.toLowerCase() ?? ''),
              services: externalServicesForUrl(u, pageUrl),
              size: estimatedTx,
              sizeNote: estimatedTx != null
                  ? null
                  : estimate is Failed<int>
                      ? 'size lookup failed'
                      : 'declared in the page, not loaded by this browser',
              estimated: estimatedTx != null,
            );
            declared++;
          }
          final rows = byUrl.values.toList()
            ..sort((a, b) {
              final bySize = (b.size ?? -1).compareTo(a.size ?? -1);
              return bySize != 0 ? bySize : a.url.compareTo(b.url);
            });
          final without = rows.where((r) => r.size == null).length;
          final estimatedCount = rows.where((r) => r.estimated).length;
          final parts = <String>[];
          if (without > 0) {
            final why = [
              ...reasons,
              if (b.platform.isWebKit)
                b.platform == BrowserPlatform.ios ? 'iOS' : 'macOS',
            ];
            parts.add('$without resource${without == 1 ? '' : 's'} '
                'without size (${why.join(', ')})');
          }
          final cacheHits = rows.where((r) => r.fromCache).length;
          if (b.resourcesTruncated) {
            parts.add('${b.resourcesDropped} resource'
                '${b.resourcesDropped == 1 ? '' : 's'} not collected '
                '(the collector buffer was full)');
          }
          if (parts.isEmpty && weight.transferLowerBound) {
            parts.add('some resources report only part of their size');
          }
          return Present(
            PageSizeModel(
              weight: weight,
              rows: rows,
              rowsWithoutSize: without,
              missingNote: parts.isEmpty ? null : parts.join('; '),
              estimatedCount: estimatedCount,
              declaredCount: declared,
              declaredNote: declared == 0
                  ? null
                  : '$declared image${declared == 1 ? '' : 's'} declared '
                      'in the page were not loaded by this browser (lazy '
                      'loading); counted at the app\'s estimated size where '
                      'known',
              estimateNote: estimatedCount == 0
                  ? null
                  : '$estimatedCount size${estimatedCount == 1 ? ' is an '
                          'estimate' : 's are estimates'} from the app\'s own '
                      'request (the browser did not report them; may differ '
                      'from what the browser loaded)',
              cacheNote: cacheHits == 0
                  ? null
                  : '$cacheHits served from the browser cache, counted at '
                      'the size a fresh load downloads (the compressed body)',
            ),
            source: DataSource.browser,
            provenance: weight.provenance,
          );
      }
  }
}
