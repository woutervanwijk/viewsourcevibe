import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../detection/engine.dart';
import '../probe_service.dart';
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
String? formatSizePair({int? decoded, int? transfer}) {
  if (decoded == null && transfer == null) return null;
  if (decoded == null) return '↓ ${_kb(transfer!)}';
  if (transfer != null && transfer != decoded) {
    return '${_kb(decoded)} (↓ ${_kb(transfer)})';
  }
  return _kb(decoded);
}

/// One loaded file. [size] is what the list is sorted and shared by: the
/// transfer size for images (WebKit's decoded size is a pixel buffer), else
/// decoded, else transfer. Null = unknown, see [sizeNote].
class PageSizeRow {
  final String url;

  /// script, style, image, document or other.
  final String type;
  final bool isPage;

  /// An audio/video file: no thumbnail can be shown for it.
  final bool isAudioVideo;
  final List<Entity> services;
  final int? size;
  final int? transfer;

  /// Size shown in the row: image = transfer only.
  final int? shownDecoded;

  /// Why the size is unknown (null when it is known).
  final String? sizeNote;

  const PageSizeRow({
    required this.url,
    required this.type,
    required this.isPage,
    required this.isAudioVideo,
    required this.services,
    required this.size,
    required this.transfer,
    required this.shownDecoded,
    required this.sizeNote,
  });

  /// "12 KB (↓ 4 KB)" or "size unknown (reason)".
  String get sizeLabel =>
      formatSizePair(decoded: shownDecoded, transfer: transfer) ??
      'size unknown${sizeNote == null ? '' : ' ($sizeNote)'}';
}

class PageSizeModel {
  final PageWeight weight;
  final List<PageSizeRow> rows;

  /// Rows without any size.
  final int rowsWithoutSize;

  /// Explains what is missing from the totals; null when nothing is.
  final String? missingNote;

  const PageSizeModel({
    required this.weight,
    required this.rows,
    required this.rowsWithoutSize,
    required this.missingNote,
  });

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

String _reasonWord(Observed<int> o) => switch (o) {
      Unavailable<int>(reason: final r, detail: final d) => switch (r) {
          // "cross-origin" only when the collector said so.
          UnavailableReason.blockedByPlatform ||
          UnavailableReason.blockedBySite ||
          UnavailableReason.notExposedToPage when d.contains('cross-origin') =>
            'cross-origin',
          UnavailableReason.blockedByPlatform => 'blocked by the platform',
          UnavailableReason.blockedBySite => 'blocked by the site',
          UnavailableReason.notExposedToPage => 'not exposed to the page',
          UnavailableReason.servedFromCache => 'served from cache',
          _ => 'not reported by the platform',
        },
      Failed<int>() => 'failed',
      _ => 'not reported',
    };

/// The Page size tab's data. Not Present when the browser has not (yet)
/// reported resources: the state says why (never an empty page).
Observed<PageSizeModel> derivePageSize(PageInspection p) {
  final browser = p.browser;
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
          final weight = derivePageWeight(p)!;
          final pageUrl = b.url.toString();
          final page = _normalizeUrl(pageUrl);
          final byUrl = <String, PageSizeRow>{};
          final reasons = <String>{};
          for (final r in entries) {
            final url = r.url;
            if (url.isEmpty || url.startsWith('data:')) continue;
            final isPage = page.isNotEmpty && _normalizeUrl(url) == page;
            final type = isPage
                ? 'document'
                : ProbeService.categorizeResource(url, pageUrl);
            final tx = r.transfer is Present<int>
                ? (r.transfer as Present<int>).value
                : null;
            final dec = r.decoded is Present<int>
                ? (r.decoded as Present<int>).value
                : null;
            final isImage = type == 'image';
            // Images: the transfer size only (decoded is never used).
            final int? size = isImage ? tx : (dec ?? tx);
            String? note;
            if (size == null) {
              note = _reasonWord(r.transfer);
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
              transfer: tx,
              shownDecoded: isImage ? tx : dec,
              sizeNote: note,
            );
            final old = byUrl[url];
            if (old == null || (row.size ?? -1) > (old.size ?? -1)) {
              byUrl[url] = row;
            }
          }
          final rows = byUrl.values.toList()
            ..sort((a, b) {
              final bySize = (b.size ?? -1).compareTo(a.size ?? -1);
              return bySize != 0 ? bySize : a.url.compareTo(b.url);
            });
          final without = rows.where((r) => r.size == null).length;
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
          if (b.resourcesTruncated) {
            parts.add('${b.resourcesDropped} resource'
                '${b.resourcesDropped == 1 ? '' : 's'} not collected '
                '(the browser buffer was full)');
          }
          if (parts.isEmpty && weight.isPartial) {
            parts.add('some resources report only part of their size');
          }
          return Present(
            PageSizeModel(
              weight: weight,
              rows: rows,
              rowsWithoutSize: without,
              missingNote: parts.isEmpty ? null : parts.join('; '),
            ),
            source: DataSource.browser,
            provenance: weight.provenance,
          );
      }
  }
}
