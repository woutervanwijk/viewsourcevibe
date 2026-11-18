import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/batch_summary.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';
import 'package:view_source_vibe/services/site_data_cleaner.dart' as cleaner;

/// Unfinished analyses by name; empty when the page is ready to export. A
/// finished detection scan that failed or checked nothing is not pending.
List<String> pendingAnalyses(HtmlService s) => [
      if (s.isLoading) 'loading',
      if (!s.store.current.browserSettled) 'browserSettled',
      if (s.detectionsView.scanning) 'detections',
      if (s.generalView is Pending) 'general',
      if (s.securityView is Pending) 'security',
      if (s.cookiesView is Pending) 'cookies',
      if (s.sovereigntyState is Pending) 'sovereignty',
    ];

final _schemePrefix = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(?!\d)');

/// One URL per line. Blank lines and lines starting with '#' are skipped; a
/// line without a scheme gets 'https://'. Only http/https with a host
/// survive (a line with whitespace inside it is rejected); duplicates (after
/// normalising) are dropped; at most [max] (the rest is rejected).
({List<Uri> urls, List<String> rejected}) parseBatchInput(String text,
    {int max = 50}) {
  final urls = <Uri>[];
  final rejected = <String>[];
  final seen = <String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final uri = RegExp(r'\s').hasMatch(line)
        ? null
        : Uri.tryParse(line.contains('://') || _schemePrefix.hasMatch(line)
            ? line
            : 'https://$line');
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      rejected.add(line);
      continue;
    }
    final key = '${uri.scheme}://${uri.host}:${uri.port}'
        '${uri.path.isEmpty ? '/' : uri.path}?${uri.query}';
    if (!seen.add(key)) continue;
    if (urls.length >= max) {
      rejected.add(line);
      continue;
    }
    urls.add(uri);
  }
  return (urls: urls, rejected: rejected);
}

class BatchOptions {
  final bool clearSiteData;
  final Duration timeout;
  final Duration linger;
  final bool freshLoad;
  const BatchOptions({
    this.clearSiteData = true,
    this.timeout = const Duration(seconds: 90),
    this.linger = const Duration(seconds: 5),
    this.freshLoad = false,
  });
}

abstract interface class BatchTarget {
  Future<void> open(Uri url);
  List<String> pending();
  void collectLate();
  Future<void> clearSiteData(Uri url);
  Future<void> measureFreshLoad();
  void watchSovereignty(bool watching);

  /// The app's own request or the browser got the page.
  bool loaded();

  /// Why the app's own request failed; null when it did not.
  String? loadFailure();

  /// The target still shows the page opened for [url] (the user did not
  /// navigate elsewhere).
  bool stillOn(Uri url);
  InspectionSummary summary();
  List<int> package();
}

class HtmlServiceBatchTarget implements BatchTarget {
  final HtmlService service;
  HtmlServiceBatchTarget(this.service);

  /// Store generation right after [open].
  int? _generation;

  @override
  Future<void> open(Uri url) async {
    _generation = null;
    await service.loadFromUrl(url.toString(),
        switchToTab: HtmlService.browserTab);
    _generation = service.store.current.generation;
  }

  @override
  List<String> pending() => pendingAnalyses(service);

  @override
  void collectLate() => service.onBrowserResourcesChanged();

  @override
  Future<void> clearSiteData(Uri url) => cleaner.clearSiteData(url);

  @override
  Future<void> measureFreshLoad() => service.measureFreshLoad();

  @override
  void watchSovereignty(bool watching) => service.watchSovereignty(watching);

  @override
  bool loaded() {
    final p = service.store.current;
    final server = p.server;
    return (server is Present<ServerSnapshot> &&
            server.value.hops.isNotEmpty) ||
        p.browser is Present;
  }

  @override
  String? loadFailure() => switch (service.store.current.server) {
        Failed(:final error) => error,
        _ => null,
      };

  @override
  bool stillOn(Uri url) {
    final p = service.store.current;
    final target = p.target;
    return p.generation == _generation &&
        target is UrlTarget &&
        HtmlService.sameUrl(target.url, url);
  }

  @override
  InspectionSummary summary() => service.summary;

  @override
  List<int> package() => InspectionExportService().buildPackageBytes(service);
}

/// Visits sites one by one through the live browser and exports each.
class BatchRunner extends ChangeNotifier {
  final BatchTarget _target;
  final Duration _poll;

  /// Wait after opening a page before polling, and after the late collect.
  final Duration _settle;
  final Duration _lateWait;
  final Future<Directory> Function() _workDirFactory;

  BatchRunner(
    BatchTarget target, {
    Duration poll = const Duration(milliseconds: 500),
    Duration settle = const Duration(seconds: 2),
    Duration lateWait = const Duration(seconds: 3),
    Future<Directory> Function()? workDir,
  })  : _target = target,
        _poll = poll,
        _settle = settle,
        _lateWait = lateWait,
        _workDirFactory = workDir ?? _defaultWorkDir;

  static Future<Directory> _defaultWorkDir() async {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final base = await getTemporaryDirectory();
    return Directory(path.join(base.path, 'batch-$stamp'))
        .create(recursive: true);
  }

  bool _running = false;
  bool _cancelled = false;
  int _index = 0;
  int _total = 0;
  Uri? _currentUrl;
  List<String> _currentPending = const [];
  String _phase = '';
  String? _error;
  Directory? _dir;
  String? _stamp;
  final List<BatchRow> _rows = [];
  final Set<String> _slugs = {};

  bool get running => _running;
  int get index => _index;
  int get total => _total;
  Uri? get currentUrl => _currentUrl;
  List<String> get currentPending => _currentPending;

  /// Step of the current site: 'clearing', 'loading', 'waiting',
  /// 'collecting', 'measuring' or 'exporting'.
  String get phase => _phase;
  List<BatchRow> get rows => List.unmodifiable(_rows);

  /// Set when the run ended outside any site (e.g. no work directory).
  String? get error => _error;

  /// Forgets the finished batch (hides the banner).
  void dismiss() {
    if (_running) return;
    _rows.clear();
    _error = null;
    _deleteWorkDir();
    notifyListeners();
  }

  void _deleteWorkDir() {
    final dir = _dir;
    _dir = null;
    try {
      if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  void _setPhase(String phase) {
    _phase = phase;
    notifyListeners();
  }

  void cancel() {
    if (_running) _cancelled = true;
  }

  Future<void> run(List<Uri> urls,
      {BatchOptions options = const BatchOptions()}) async {
    if (_running) return;
    _running = true;
    _cancelled = false;
    _error = null;
    _rows.clear();
    _slugs.clear();
    _index = 0;
    _total = urls.length;
    _deleteWorkDir();
    _stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    notifyListeners();
    try {
      _target.watchSovereignty(true);
      final dir = _dir = await _workDirFactory();
      await Directory(path.join(dir.path, 'sites')).create(recursive: true);
      for (var i = 0; i < urls.length && !_cancelled; i++) {
        _index = i;
        _currentUrl = urls[i];
        _currentPending = const [];
        notifyListeners();
        final row = await _visit(urls[i], options, dir);
        if (row == null) break; // cancelled mid-site
        _rows.add(row);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      try {
        _target.watchSovereignty(false);
      } catch (_) {}
      _running = false;
      _currentUrl = null;
      _currentPending = const [];
      _phase = '';
      notifyListeners();
    }
  }

  String _uniqueSlug(Uri url) {
    final base = inspectionSlug(url.toString());
    var slug = base;
    for (var n = 2; !_slugs.add(slug); n++) {
      slug = '$base-$n';
    }
    return slug;
  }

  /// Null when cancelled before the site was exported.
  Future<BatchRow?> _visit(Uri url, BatchOptions o, Directory dir) async {
    final slug = _uniqueSlug(url);
    try {
      if (o.clearSiteData) {
        _setPhase('clearing');
        await _target.clearSiteData(url);
      }
      _setPhase('loading');
      await _target.open(url);
      await Future<void>.delayed(_settle);
      final clock = Stopwatch()..start();
      var pending = _target.pending();
      while (pending.isNotEmpty && clock.elapsed < o.timeout && !_cancelled) {
        _currentPending = pending;
        _setPhase('waiting');
        await Future<void>.delayed(_poll);
        pending = _target.pending();
      }
      if (_cancelled) return null;
      _currentPending = const [];
      _setPhase('collecting');
      await Future<void>.delayed(o.linger);
      _target.collectLate();
      await Future<void>.delayed(_lateWait);
      if (_cancelled) return null;
      if (o.freshLoad) {
        _setPhase('measuring');
        await _target.measureFreshLoad();
      }
      _setPhase('exporting');
      // Everything below up to the write is read at one moment, no await.
      if (!_target.stillOn(url)) {
        return BatchRow(
            url: url,
            slug: slug,
            state: 'failed',
            error: 'navigated away during the batch');
      }
      pending = _target.pending();
      final loaded = _target.loaded();
      final failure = loaded ? null : _target.loadFailure();
      final summary = _target.summary();
      final bytes = _target.package();
      await File(path.join(dir.path, 'sites', '$slug.zip'))
          .writeAsBytes(bytes, flush: true);
      return BatchRow(
        url: url,
        slug: slug,
        state: !loaded ? 'failed' : (pending.isEmpty ? 'done' : 'timed out'),
        pending: pending,
        error: loaded ? null : (failure ?? 'the site did not load'),
        summary: summary,
      );
    } catch (e) {
      return BatchRow(
          url: url, slug: slug, state: 'failed', error: e.toString());
    }
  }

  /// Writes the batch zip and returns it. Null when no site finished.
  Future<File?> writeZip() async {
    final dir = _dir;
    if (dir == null || _rows.isEmpty) return null;
    final now = DateTime.now().toUtc();
    // One name per run: a repeated export overwrites it.
    final file = File(path.join(dir.path, 'viewsourcevibe-batch-$_stamp.zip'));
    final rows = List.of(_rows);
    final encoder = ZipFileEncoder()..create(file.path);
    try {
      void text(String name, String content) =>
          encoder.addArchiveFile(ArchiveFile.string(name, content));
      text('summary.html', batchSummaryHtml(rows, exportedAt: now));
      text('summary.csv', batchSummaryCsv(rows));
      text(
          'summary.json',
          const JsonEncoder.withIndent('  ')
              .convert(batchSummaryJson(rows, exportedAt: now)));
      for (final r in rows) {
        final f = File(path.join(dir.path, r.package));
        if (r.summary != null && f.existsSync()) {
          // Stored: the nested zips are already compressed.
          await encoder.addFile(f, r.package, ZipFileEncoder.store);
        }
      }
    } finally {
      await encoder.close();
    }
    return file;
  }
}
