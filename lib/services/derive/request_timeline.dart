import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/format_utils.dart';
import '../probe_service.dart';
import 'observed_text.dart';
import 'page_size.dart' show formatSizePair, sizeReasonWord;
import 'page_weight.dart';
import 'probe_general.dart'
    show HopLine, RedirectStep, hopLinesOf, redirectStepsOf;

/// document, style, script, image, font, fetch or other, from the URL.
String resourceTypeOf(String name) {
  final byExtension = ProbeService.resourceTypeFromExtension(name);
  if (byExtension != null) return byExtension;

  final lower = name.toLowerCase();
  if (lower.endsWith('.js') || lower.contains('.js?')) return 'script';
  if (lower.endsWith('.css') || lower.contains('.css?')) return 'style';
  if (lower.contains('/font') ||
      lower.endsWith('.woff') ||
      lower.endsWith('.woff2') ||
      lower.endsWith('.ttf')) {
    return 'font';
  }
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.svg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.avif') ||
      lower.contains('/image')) {
    return 'image';
  }
  if (lower.contains('/api/') ||
      lower.contains('graphql') ||
      lower.contains('xhr')) {
    return 'fetch';
  }
  if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'document';
  return 'other';
}

String _shortName(String name) {
  final uri = Uri.tryParse(name);
  final path = uri?.path ?? name;
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return uri?.host ?? name;
  return parts.last.length > 48
      ? '${parts.last.substring(0, 45)}...'
      : parts.last;
}

/// "850ms" or "1.20s".
String formatMs(double value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(2)}s'
    : '${value.round()}ms';

/// One request of the page. [start] / [duration] are null when the browser
/// did not report them: such a row is drawn without a bar.
class TimelineRow {
  final String url;
  final String shortName;
  final String type;
  final double? start;
  final double? duration;
  final String timingLabel;
  final String sizeLabel;

  const TimelineRow({
    required this.url,
    required this.shortName,
    required this.type,
    required this.start,
    required this.duration,
    required this.timingLabel,
    required this.sizeLabel,
  });

  bool get hasBar => start != null && duration != null;
}

class TimelineModel {
  /// Final URL of the app's request, else the browser's URL.
  final String? url;

  /// "App request: 200 OK" (the server snapshot, not the browser's).
  final String appStatus;
  final List<RedirectStep> redirects;
  final Observed<List<TimelineRow>> rows;
  final String resourcesLabel;
  final String transferLabel;
  final String? decodedLabel;

  /// End of the last request that has timing, in ms; 0 without any.
  final double timelineEnd;
  final int rowsWithoutTiming;
  final String? note;

  const TimelineModel({
    required this.url,
    required this.appStatus,
    required this.redirects,
    required this.rows,
    required this.resourcesLabel,
    required this.transferLabel,
    required this.decodedLabel,
    required this.timelineEnd,
    required this.rowsWithoutTiming,
    required this.note,
  });
}

String _sizeLabel(ResourceEntry r, String type) {
  final isImage = type == 'image';
  final tx =
      r.transfer is Present<int> ? (r.transfer as Present<int>).value : null;
  final dec =
      r.decoded is Present<int> ? (r.decoded as Present<int>).value : null;
  // Images: the transfer size only (WebKit's decoded size is a pixel buffer).
  final text = formatSizePair(decoded: isImage ? tx : dec, transfer: tx);
  if (text != null) return r.fromCache ? '$text · cached' : text;
  return 'size unknown (${sizeReasonWord(r.transfer)})';
}

String _timingLabel(ResourceEntry r) {
  final s = r.startTime;
  final d = r.duration;
  if (s is Present<double> && d is Present<double>) {
    return '${formatMs(s.value)} / ${formatMs(d.value < 0 ? 0 : d.value)}';
  }
  final why = s is! Present<double> ? s : d;
  return 'timing unknown (${notPresentText(why)})';
}

/// The Request Timeline tab. The resources come from the browser snapshot;
/// the redirect chain and the status from the server snapshot (each labelled
/// by where it came from). A request without timing is kept, without a bar.
Observed<TimelineModel> deriveTimeline(PageInspection p) {
  switch (p.target) {
    case NoTarget():
      return const Unavailable(UnavailableReason.notApplicable,
          'Load a URL to view the request timeline.');
    case FileTarget():
      return const Unavailable(UnavailableReason.notApplicable,
          'The request timeline is measured by the browser and is not available for a local file.');
    case UrlTarget():
      break;
  }

  final server = p.server;
  final browser = p.browser;
  final serverOk =
      server is Present<ServerSnapshot> && server.value.hops.isNotEmpty;
  final snapshot = browser is Present<BrowserSnapshot> ? browser.value : null;
  final res = snapshot?.resources ?? notPresentAs<List<ResourceEntry>>(browser);

  final List<HopLine> lines = serverOk ? hopLinesOf(server.value) : const [];
  final redirects = serverOk ? redirectStepsOf(lines) : const <RedirectStep>[];
  final appStatus = serverOk
      ? 'App request: ${lines.last.text}'
      : 'App request: ${unknownText(server)}';

  String? url;
  if (serverOk && server.value.finalUrl is Present<Uri>) {
    url = (server.value.finalUrl as Present<Uri>).value.toString();
  } else if (snapshot != null) {
    url = snapshot.url.toString();
  } else {
    url = (p.target as UrlTarget).url.toString();
  }

  final Observed<List<TimelineRow>> rows;
  var end = 0.0;
  var without = 0;
  String? note;
  if (res is Present<List<ResourceEntry>>) {
    final list = <TimelineRow>[];
    for (final r in res.value) {
      final type = resourceTypeOf(r.url);
      final start = r.startTime is Present<double>
          ? (r.startTime as Present<double>).value
          : null;
      final dur = r.duration is Present<double>
          ? (r.duration as Present<double>).value
          : null;
      list.add(TimelineRow(
        url: r.url,
        shortName: _shortName(r.url),
        type: type,
        start: start,
        duration: dur == null ? null : (dur < 0 ? 0 : dur),
        timingLabel: _timingLabel(r),
        sizeLabel: _sizeLabel(r, type),
      ));
    }
    final timed = list.where((r) => r.hasBar).toList()
      ..sort((a, b) {
        final byStart = a.start!.compareTo(b.start!);
        return byStart != 0 ? byStart : b.duration!.compareTo(a.duration!);
      });
    final untimed = list.where((r) => !r.hasBar).toList();
    without = untimed.length;
    for (final r in timed) {
      final e = r.start! + r.duration!;
      if (e > end) end = e;
    }
    final notes = <String>[
      if (without > 0)
        '$without resource${without == 1 ? ' has' : 's have'} no timing '
            '(the platform did not report it); listed without a bar',
      if (snapshot != null && snapshot.resourcesTruncated)
        '${snapshot.resourcesDropped} resource'
            '${snapshot.resourcesDropped == 1 ? '' : 's'} not collected '
            '(the collector buffer was full)',
    ];
    note = notes.isEmpty ? null : notes.join('; ');
    rows = Present([...timed, ...untimed], source: DataSource.browser);
  } else {
    rows = notPresentAs(res);
  }

  final weight = derivePageWeight(p);
  String transfer;
  String? decoded;
  if (weight == null || weight.transfer == null) {
    transfer = 'Size unknown';
  } else {
    transfer =
        '${weight.transferPrefix}${FormatUtils.formatBytes(weight.transfer!)}';
  }
  if (weight != null &&
      weight.decoded != null &&
      weight.decoded != weight.transfer) {
    decoded =
        '${weight.decodedPrefix}${FormatUtils.formatBytes(weight.decoded!)} decoded';
  }

  return Present(
      TimelineModel(
        url: url,
        appStatus: appStatus,
        redirects: redirects,
        rows: rows,
        resourcesLabel: res is Present<List<ResourceEntry>>
            ? '${res.value.length} resources'
            : unknownText(res),
        transferLabel: transfer,
        decodedLabel: decoded,
        timelineEnd: end,
        rowsWithoutTiming: without,
        note: note,
      ),
      source: DataSource.browser,
      provenance: Provenance.derived);
}
