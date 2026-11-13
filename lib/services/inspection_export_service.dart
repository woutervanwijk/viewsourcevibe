import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/cookies_view.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/derive/observed_text.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart';
import 'package:view_source_vibe/services/derive/request_timeline.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';
import 'package:view_source_vibe/services/file_system_service.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/inspection_export_data.dart';
import 'package:view_source_vibe/services/observed_json.dart';

class InspectionExportService {
  static const int packageFormatVersion = 1;

  Future<File> exportCurrentInspection(HtmlService htmlService) async {
    final bytes = buildPackageBytes(htmlService);
    final fileSystem = FileSystemService();
    final filename = _filenameFor(htmlService.store.current);

    return fileSystem.saveBinaryToDownloadsDirectory(
      filename: filename,
      bytes: bytes,
      subDirectory: 'inspection-packages',
    );
  }

  Future<File> createShareableInspectionPackage(HtmlService htmlService) async {
    return FileSystemService().saveBinaryToTempFile(
      filename: _filenameFor(htmlService.store.current),
      bytes: buildPackageBytes(htmlService),
    );
  }

  static String _filenameFor(PageInspection p) {
    final t = p.target;
    return switch (t) {
      UrlTarget() => _packageFilename(t.url.toString()),
      FileTarget() => _packageFilename(t.file.name),
      NoTarget() => throw StateError('No file or URL loaded'),
    };
  }

  List<int> buildPackageBytes(HtmlService htmlService) {
    final p = htmlService.store.current;
    final target = p.target;
    if (target is NoTarget) {
      throw StateError('No file or URL loaded');
    }

    final exportedAt = DateTime.now().toUtc().toIso8601String();
    final archive = Archive();

    void addString(String name, String content) {
      archive.addFile(ArchiveFile.string(name, content));
    }

    void addJson(String name, Object? value) {
      addString(
        name,
        const JsonEncoder.withIndent('  ').convert(_jsonSafe(value)),
      );
    }

    final name = switch (target) {
      UrlTarget() => _urlName(target.url),
      FileTarget() => target.file.name,
      NoTarget() => '',
    };
    final path = switch (target) {
      UrlTarget() => target.url.toString(),
      FileTarget() => target.file.path,
      NoTarget() => '',
    };
    final block = htmlService.blockPage;
    // What was measured on a block page is not the site's: the analysis is
    // unavailable, with the block page's own result kept beside it.
    Map<String, Object?> unlessBlocked(Map<String, Object?> json) =>
        block == null
            ? json
            : {
                'status': 'unavailable',
                'reason': UnavailableReason.blockedBySite.name,
                'detail': block.detail,
                'onBlockPage': json,
              };
    final manifest = {
      'format': 'view-source-vibe-inspection-package',
      'formatVersion': packageFormatVersion,
      'exportedAt': exportedAt,
      'source': InspectionExportData.manifestSource(p, name, path),
      // The browser got an error, block or challenge page instead of the site.
      'blockPage':
          block == null ? null : {...block.toMap(), 'detail': block.detail},
    };

    // Texts of the documents we hold. A source we do not hold is not written.
    final serverSource = htmlService.serverSource;
    final dom = p.browser is Present<BrowserSnapshot> &&
            (p.browser as Present<BrowserSnapshot>).value.renderedDom
                is Present<RenderedDom>
        ? ((p.browser as Present<BrowserSnapshot>).value.renderedDom
                as Present<RenderedDom>)
            .value
            .text
        : null;
    final localFileText = target is FileTarget && !target.file.isBinary
        ? target.file.text.text
        : null;
    final diff =
        serverSource != null && dom != null ? _lineDiff(serverSource, dom) : '';

    final general = htmlService.generalView;
    final security = htmlService.securityView;
    final cookies = htmlService.cookiesView;
    final metadata = htmlService.metadataState;
    final detections = htmlService.detectionsView;
    final sovereignty = htmlService.sovereigntyState;

    final probeJson = InspectionExportData.server(p);
    final browserJson = InspectionExportData.browser(p);
    final headersJson = InspectionExportData.headers(p);
    final cookiesJson = InspectionExportData.cookies(cookies);
    final redirectsJson = InspectionExportData.redirects(general);
    final timelineJson = InspectionExportData.timeline(p);
    final scorecardJson = InspectionExportData.securityScorecard(security);
    final certificateJson = InspectionExportData.certificate(security);
    final robotsJson = InspectionExportData.robots(general);
    final weightJson = unlessBlocked(InspectionExportData.pageWeight(p));
    final metadataJson = unlessBlocked(
        observedJson(metadata, (m) => m.data, source: DataSource.browser));
    final detectionsJson = unlessBlocked({
      'status': detections.failure != null
          ? 'failed'
          : detections.complete
              ? 'present'
              : 'pending',
      if (detections.failure != null) 'detail': detections.failure,
      'checked': detections.sources.line,
      'value': [for (final d in detections.detections) d.toMap()],
    });
    final sovereigntyJson = observedJson(sovereignty, (r) => r.toJson(),
        source: DataSource.server, provenance: Provenance.derived);

    addJson('manifest.json', manifest);
    addString(
      'report.html',
      _buildHtmlReport(
        manifest: manifest,
        general: general,
        security: security,
        cookies: cookies,
        timeline: htmlService.timelineView,
        metadata: metadata,
        services: servicesByCategory(detections.detections),
        probeJson: probeJson,
        browserJson: browserJson,
        headersJson: headersJson,
        cookiesJson: cookiesJson,
        timelineJson: timelineJson,
        weightJson: weightJson,
        hasServerSource: serverSource != null,
        hasBrowserSource: dom != null,
      ),
    );

    if (dom != null) addString('source/browser-dom.html', dom);
    if (serverSource != null) addString('source/server.html', serverSource);
    if (localFileText != null) {
      addString('source/local-file.txt', localFileText);
    }
    if (diff.isNotEmpty) addString('source/diff.patch', diff);

    addJson('network/probe.json', probeJson);
    addJson('network/browser-probe.json', browserJson);
    addJson('network/headers.json', headersJson);
    addJson('network/cookies.json', cookiesJson);
    addJson('network/redirects.json', redirectsJson);
    addJson('network/timeline.json', timelineJson);
    addJson('analysis/sovereignty.json', sovereigntyJson);

    addJson('analysis/metadata.json', metadataJson);
    addJson('analysis/detections.json', detectionsJson);
    addJson('analysis/security-scorecard.json', scorecardJson);
    addJson('analysis/certificate.json', certificateJson);
    addJson('analysis/robots-sitemap.json', robotsJson);
    addJson(
        'analysis/structured-data.json',
        unlessBlocked(observedJson(
            metadata, (m) => m.data['structuredData'] ?? const [],
            source: DataSource.browser)));
    addJson('analysis/page-weight.json', weightJson);

    // The raw collector payload of the last sync, so real-device fixtures can
    // be recorded later. Cookie and storage values are redacted (R22).
    final browserPayload = htmlService.browserDebugPayload;
    if (browserPayload != null) {
      addString('debug/browser-payload.json', _payloadJson(browserPayload));
    }

    return ZipEncoder().encode(archive);
  }

  /// The payload as pretty JSON with cookie and storage values removed (names
  /// and UTF-8 byte lengths stay), so the package can be shared. A payload
  /// that is not JSON is reduced to its length.
  static String _payloadJson(String raw) {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('not an object');
      return encoder
          .convert(_redactPayload(Map<String, dynamic>.from(decoded)));
    } catch (_) {
      return encoder.convert({
        'unparsablePayload': {'type': 'text', 'length': raw.length}
      });
    }
  }

  static int _bytes(Object? v) => utf8.encode('${v ?? ''}').length;

  static Map<String, dynamic> _redactPayload(Map<String, dynamic> p) {
    final out = Map<String, dynamic>.from(p);
    final cookies = p['cookies'];
    if (cookies is Map) {
      final c = Map<String, dynamic>.from(cookies);
      final rawCookies = c.remove('raw');
      if (rawCookies is String) {
        c['redacted'] = [
          for (final part in rawCookies.split(';'))
            if (part.trim().isNotEmpty)
              {
                'name': part.trim().split('=').first,
                'bytes': _bytes(part.trim().contains('=')
                    ? part.trim().substring(part.trim().indexOf('=') + 1)
                    : ''),
              }
        ];
      }
      out['cookies'] = c;
    }
    final storage = p['storage'];
    if (storage is Map) {
      final st = <String, dynamic>{};
      storage.forEach((area, value) {
        if (value is Map) {
          final a = Map<String, dynamic>.from(value);
          final items = a['items'];
          if (items is List) {
            a['items'] = [
              for (final i in items)
                if (i is Map) {'k': i['k'], 'bytes': _bytes(i['v'])}
            ];
          }
          st['$area'] = a;
        } else {
          st['$area'] = value;
        }
      });
      out['storage'] = st;
    }
    return out;
  }

  static String buildPackageFilename(HtmlFile file) => _packageFilename(
      file.isUrl && file.path.isNotEmpty ? file.path : file.name);

  static String _urlName(Uri url) {
    final last = url.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    return last ?? url.host;
  }

  static String _packageFilename(String source) {
    final slug = _slugFor(source);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_')
        .replaceFirst(RegExp(r'Z$'), 'Z');
    return 'viewsourcevibe-$slug-$stamp.zip';
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Uri) return value.toString();
    if (value is Map) {
      return value
          .map((key, item) => MapEntry(key.toString(), _jsonSafe(item)));
    }
    if (value is Iterable) {
      return value.map((item) => _jsonSafe(item)).toList();
    }
    return value.toString();
  }

  /// "unknown (reason)" for a state that is not Present, else [present].
  static String _obs<T>(Observed<T> o, String Function(T) present) =>
      o is Present<T> ? present(o.value) : unknownText(o);

  static String _buildHtmlReport({
    required Map<String, dynamic> manifest,
    required Observed<GeneralModel> general,
    required Observed<SecurityModel> security,
    required Observed<CookiesModel> cookies,
    required Observed<TimelineModel> timeline,
    required Observed<MetadataModel> metadata,
    required Map<String, List<String>> services,
    required Map<String, Object?> probeJson,
    required Map<String, Object?> browserJson,
    required Map<String, Object?> headersJson,
    required Map<String, Object?> cookiesJson,
    required Map<String, Object?> timelineJson,
    required Map<String, Object?> weightJson,
    required bool hasServerSource,
    required bool hasBrowserSource,
  }) {
    final source = manifest['source'] as Map<String, Object?>;
    String observedText(Object? o) {
      if (o is! Map) return 'unknown';
      if (o['status'] == 'present') return '${o['value']}';
      final why = o['detail'] ?? o['reason'] ?? o['status'];
      return 'unknown ($why)';
    }

    final g = general is Present<GeneralModel> ? general.value : null;
    final status = g?.status;
    final data =
        metadata is Present<MetadataModel> ? metadata.value.data : null;
    String meta(String key) {
      if (data == null) return unknownText(metadata);
      final v = data[key];
      return v == null || v.toString().isEmpty ? 'not set' : v.toString();
    }

    final probeRows = <List<String>>[];
    if (status != null) {
      probeRows.add([
        'App request status',
        _obs(status, (s) => s.finalStatusText),
      ]);
      if (status is Present<ServerStatus>) {
        final s = status.value;
        probeRows
          ..add(['Final URL', s.finalUrlLabel])
          ..add(['Content-Type', s.contentType ?? 'not sent by the server'])
          ..add(['Content-Length', s.contentLengthLabel])
          ..add(['Body received', s.bodyLabel])
          ..add(['Remote address', s.remoteAddressLabel])
          ..add(['Response time', s.timingLabel])
          ..add(['User-Agent used', s.userAgent]);
      }
    } else {
      probeRows.add(['App request', unknownText(general)]);
    }
    final browserRows = <List<String>>[];
    if (g != null) {
      browserRows.addAll([
        ['Browser', _obs(g.browser, (b) => '${b.environment}, ${b.url}')],
        ['Requests', _obs(g.browser, (b) => b.resourcesLabel)],
        ['Total size', _obs(g.browser, (b) => b.totalSizeLabel)],
      ]);
    }

    final cookieRows = cookies is Present<CookiesModel>
        ? [
            for (final c in cookies.value.rows)
              [
                c.name,
                c.domain,
                c.category,
                c.sameSite,
                c.secure,
                c.httpOnly,
                '${c.valueBytes} bytes (value not exported) · ${c.source}',
              ]
          ]
        : <List<String>>[];
    final headerRows = <List<String>>[];
    if (headersJson['status'] == 'present') {
      final hops = ((headersJson['value'] as Map)['hops'] as List);
      if (hops.isNotEmpty) {
        final h = (hops.last as Map)['headers'] as Map;
        for (final e in h.entries) {
          headerRows.add(['${e.key}', (e.value as List).join('\n')]);
        }
      }
    }
    final securityRows = <List<String>>[];
    if (security is Present<SecurityModel> &&
        security.value.audit is Present<SecurityAudit>) {
      for (final r
          in (security.value.audit as Present<SecurityAudit>).value.rows) {
        securityRows.add([
          r.name,
          r.value ?? 'Not sent by the server',
          r.value == null ? 'Review' : 'Present'
        ]);
      }
    }
    final certificateRows = <List<String>>[];
    if (security is Present<SecurityModel>) {
      final c = security.value.certificate;
      if (c is Present<CertificateModel>) {
        certificateRows
          ..add(['Validity', c.value.validityLabel])
          ..add(['Host', c.value.hostLabel])
          ..add(['Valid from', c.value.validFrom])
          ..add(['Valid until', c.value.validUntil]);
      } else {
        certificateRows.add(['Certificate', unknownText(c)]);
      }
    }
    final robots = g?.robots;
    final robotsRows = robots is Present<RobotsCard>
        ? [
            ['robots.txt', robots.value.robotsLabel],
            ['Sitemaps', robots.value.sitemapsLabel],
            ['Disallow', robots.value.disallowLabel],
            ['Allow', robots.value.allowLabel],
            if (robots.value.truncatedNote != null)
              ['Note', robots.value.truncatedNote!],
          ]
        : [
            ['Robots / sitemap', unknownText(robots ?? general)]
          ];
    final redirectRows = status is Present<ServerStatus>
        ? [
            for (final r in status.value.redirects)
              [r.statusText, r.from, r.to ?? 'no Location header']
          ]
        : <List<String>>[];
    final timelineRows = <List<String>>[];
    if (timeline is Present<TimelineModel>) {
      final rows = timeline.value.rows;
      if (rows is Present<List<TimelineRow>>) {
        for (final r in rows.value) {
          timelineRows.add([
            r.type,
            r.url,
            r.start == null ? 'unknown' : '${r.start!.round()} ms',
            r.duration == null ? 'unknown' : '${r.duration!.round()} ms',
            r.sizeLabel,
          ]);
        }
      }
    }
    final timelineState = timeline is Present<TimelineModel>
        ? (timeline.value.rows is Present
            ? null
            : unknownText(timeline.value.rows))
        : unknownText(timeline);

    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>View Source Vibe Inspection</title>
  CSS_PLACEHOLDER
</head>
<body>
<main>
  <h1>Inspection Package</h1>
  <p class="muted">Exported ${_escape(manifest['exportedAt'])} by View Source Vibe.</p>
  ${manifest['blockPage'] is Map ? '<div class="card"><strong>Not the site:</strong> ${_escape((manifest['blockPage'] as Map)['detail'])}.</div>' : ''}

  <section class="grid">
    ${_metricCard('Target', '${source['path']}')}
    ${_metricCard('Type', source['kind'] == 'url' ? 'URL' : 'Local file')}
    ${_metricCard('Size', source['size'] is Map ? observedText(source['size']) : 'unknown')}
    ${_metricCard('Last modified', observedText(source['lastModified']))}
    ${_metricCard('App request status', status == null ? unknownText(general) : _obs(status, (s) => s.finalStatusText))}
  </section>

  <h2>Included Files</h2>
  <div class="card">
    ${_pill('manifest.json')}
    ${_pill('report.html')}
    ${_pill('source/browser-dom.html', enabled: hasBrowserSource)}
    ${_pill('source/server.html', enabled: hasServerSource)}
    ${_pill('source/diff.patch', enabled: hasServerSource && hasBrowserSource)}
    ${_pill('network/*.json')}
    ${_pill('analysis/*.json')}
  </div>

  <h2>Page Summary</h2>
  <section class="grid">
    ${_metricCard('Title', meta('title'))}
    ${_metricCard('Description', meta('description'))}
    ${_metricCard('Resources', timeline is Present<TimelineModel> ? timeline.value.resourcesLabel : unknownText(timeline))}
    ${_metricCard('Cookies', cookies is Present<CookiesModel> ? '${cookies.value.total} seen${cookies.value.complete ? '' : ' (a source is unknown)'}' : unknownText(cookies))}
    ${_metricCard('Redirects', status is Present<ServerStatus> ? '${status.value.redirects.length}' : unknownText(general))}
    ${_metricCard('Page weight', observedText(weightJson))}
  </section>

  <h2>Metadata</h2>
  ${data == null ? '<div class="card muted">${_escape(unknownText(metadata))}</div>' : _table(_metadataSummary(data), [
                'Field',
                'Value'
              ])}
  <h3>Open Graph</h3>
  ${_mapTable(_mapFrom(data?['openGraph']), ['Property', 'Content'])}
  <h3>Twitter / Social</h3>
  ${_mapTable(_mapFrom(data?['twitter']), ['Property', 'Content'])}
  <h3>Structured Data</h3>
  ${_jsonCards(_listFrom(data?['structuredData']))}
  <h3>Media</h3>
  ${_jsonCards(_listFrom(_mapFrom(data?['media'])['images']), emptyText: 'No media entries captured.')}
  ${_rawDetails('Raw Metadata JSON', data ?? {'status': unknownText(metadata)})}

  <h2>Probe</h2>
  ${_table(probeRows, ['Field', 'Value'])}
  <h3>Browser Probe</h3>
  ${_table(browserRows, ['Field', 'Value'])}
  ${_rawDetails('Raw Probe JSON', probeJson)}
  ${_rawDetails('Raw Browser Probe JSON', browserJson)}

  <h2>Services</h2>
  ${_servicesTable(services)}
  <h3>External Resources</h3>
  ${_table(_serviceResourceRows(data), ['Type', 'URL'])}
  ${_rawDetails('Raw Services JSON', services)}

  <h2>Cookies</h2>
  ${cookies is Present<CookiesModel> ? '' : '<div class="card muted">${_escape(unknownText(cookies))}</div>'}
  ${_table(cookieRows, [
          'Name',
          'Domain',
          'Category',
          'SameSite',
          'Secure',
          'HttpOnly',
          'Value / Source'
        ])}
  ${_rawDetails('Raw Cookies JSON', cookiesJson)}

  <h2>Headers</h2>
  ${headersJson['status'] == 'present' ? '' : '<div class="card muted">${_escape(observedText(headersJson))}</div>'}
  ${_table(headerRows, ['Header', 'Value'])}
  ${_rawDetails('Raw Headers JSON', headersJson)}

  <h2>Security</h2>
  ${security is Present<SecurityModel> ? '' : '<div class="card muted">${_escape(unknownText(security))}</div>'}
  ${_table(securityRows, ['Check', 'Value', 'Verdict'])}
  <h3>Certificate</h3>
  ${_table(certificateRows, ['Field', 'Value'])}
  <h3>Robots / Sitemap</h3>
  ${_table(robotsRows, ['Field', 'Value'])}

  <h2>Redirect Chain</h2>
  ${_table(redirectRows, ['Status', 'From', 'To'])}

  <h2>Timeline</h2>
  ${timelineState == null ? '' : '<div class="card muted">${_escape(timelineState)}</div>'}
  ${_table(timelineRows, ['Type', 'URL', 'Start', 'Duration', 'Size'])}
  ${_rawDetails('Raw Timeline JSON', timelineJson)}
</main>
</body>
</html>'''
        .replaceFirst('CSS_PLACEHOLDER', _reportCss);
  }

  static const _reportCss = r'''<style>
    body { margin: 0; font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #1f2937; background: #f8fafc; }
    main { max-width: 1040px; margin: 0 auto; padding: 32px 20px 48px; }
    h1 { margin: 0 0 6px; font-size: 28px; }
    h2 { margin: 28px 0 12px; font-size: 18px; }
    h3 { margin: 18px 0 10px; font-size: 15px; }
    a { color: #0369a1; }
    .muted { color: #64748b; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
    .card { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 16px; }
    .label { display: block; color: #64748b; font-size: 12px; }
    .value { font-weight: 650; overflow-wrap: anywhere; }
    table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; }
    th, td { text-align: left; padding: 9px 10px; border-bottom: 1px solid #e2e8f0; vertical-align: top; }
    th { background: #eef2f7; font-size: 12px; color: #475569; }
    tr:last-child td { border-bottom: 0; }
    code { background: #e2e8f0; padding: 2px 5px; border-radius: 4px; }
    .pill { display: inline-block; padding: 2px 8px; border: 1px solid #cbd5e1; border-radius: 999px; margin: 2px 4px 2px 0; background: #fff; }
    details { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px 12px; margin-top: 12px; }
    summary { cursor: pointer; font-weight: 650; }
    pre { overflow: auto; white-space: pre-wrap; word-break: break-word; background: #0f172a; color: #e2e8f0; border-radius: 8px; padding: 12px; }
  </style>''';

  static List<List<String>> _metadataSummary(Map<String, dynamic> metadata) {
    const keys = [
      'title',
      'description',
      'canonical',
      'author',
      'generator',
      'language',
      'charset',
      'viewport',
      'themeColor',
      'robots',
      'favicon',
    ];
    return [
      for (final key in keys)
        if (metadata[key] != null && metadata[key].toString().isNotEmpty)
          [key, _compactValue(metadata[key])],
    ];
  }

  static String _metricCard(String label, String value) {
    return '<div class="card"><span class="label">${_escape(label)}</span><div class="value">${_escape(value)}</div></div>';
  }

  static String _pill(String label, {bool enabled = true}) {
    final text = enabled ? label : '$label (not available)';
    return '<span class="pill">${_escape(text)}</span>';
  }

  static String _table(List<List<String>> rows, List<String> headers) {
    if (rows.isEmpty) {
      return '<div class="card muted">No data captured.</div>';
    }
    final head = headers.map((header) => '<th>${_escape(header)}</th>').join();
    final body = rows
        .map((row) =>
            '<tr>${row.map((cell) => '<td>${_escape(cell)}</td>').join()}</tr>')
        .join();
    return '<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table>';
  }

  static String _mapTable(Map<String, dynamic> map, List<String> headers) {
    return _table(
      map.entries
          .map((entry) => [entry.key, _compactValue(entry.value)])
          .toList(),
      headers,
    );
  }

  static String _servicesTable(Map<String, dynamic> services) {
    final rows = <List<String>>[];
    for (final entry in services.entries) {
      final values = _listFrom(entry.value);
      if (values.isEmpty) {
        rows.add([entry.key, '']);
      } else {
        rows.add([entry.key, values.map(_compactValue).join(', ')]);
      }
    }
    return _table(rows, ['Category', 'Detected Services']);
  }

  static String _jsonCards(List<dynamic> items,
      {String emptyText = 'No data captured.'}) {
    if (items.isEmpty) {
      return '<div class="card muted">${_escape(emptyText)}</div>';
    }
    return items
        .map((item) =>
            '<details><summary>${_escape(_jsonCardTitle(item))}</summary><pre>${_escape(_prettyJson(item))}</pre></details>')
        .join();
  }

  static String _rawDetails(String title, Object? value) {
    return '<details><summary>${_escape(title)}</summary><pre>${_escape(_prettyJson(value))}</pre></details>';
  }

  static List<List<String>> _serviceResourceRows(
      Map<String, dynamic>? metadata) {
    if (metadata == null) return [];
    final rows = <List<String>>[];
    void addAll(String type, Object? value) {
      for (final item in _listFrom(value)) {
        rows.add([type, _resourceLabel(item)]);
      }
    }

    addAll('JavaScript', metadata['jsLinks']);
    addAll('External JavaScript', metadata['externalJsLinks']);
    addAll('CSS', metadata['cssLinks']);
    addAll('External CSS', metadata['externalCssLinks']);
    addAll('Iframe', metadata['iframeLinks']);
    addAll('External iframe', metadata['externalIframeLinks']);
    return rows;
  }

  static Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static List<dynamic> _listFrom(Object? value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList();
    return const [];
  }

  static String _resourceLabel(Object? value) {
    if (value is Map) {
      return (value['src'] ??
              value['href'] ??
              value['url'] ??
              value['name'] ??
              value.toString())
          .toString();
    }
    return value?.toString() ?? '';
  }

  static String _compactValue(Object? value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    if (value is Iterable) {
      return value.map(_compactValue).join(', ');
    }
    if (value is Map && value.length <= 3) {
      return value.entries
          .map((entry) => '${entry.key}: ${_compactValue(entry.value)}')
          .join(', ');
    }
    return _prettyJson(value);
  }

  static String _jsonCardTitle(Object? item) {
    if (item is Map) {
      return (item['@type'] ??
              item['type'] ??
              item['name'] ??
              item['headline'] ??
              'Entry')
          .toString();
    }
    return 'Entry';
  }

  static String _prettyJson(Object? value) {
    return const JsonEncoder.withIndent('  ').convert(_jsonSafe(value));
  }

  static String _lineDiff(String? before, String after) {
    if (before == null || before.isEmpty || after.isEmpty || before == after) {
      return '';
    }
    final a = const LineSplitter().convert(before);
    final b = const LineSplitter().convert(after);
    final buffer = StringBuffer()
      ..writeln('--- source/server.html')
      ..writeln('+++ source/browser-dom.html');
    final max = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < max; i++) {
      final left = i < a.length ? a[i] : null;
      final right = i < b.length ? b[i] : null;
      if (left == right) continue;
      buffer.writeln('@@ line ${i + 1} @@');
      if (left != null) buffer.writeln('-$left');
      if (right != null) buffer.writeln('+$right');
    }
    return buffer.toString();
  }

  static String _slugFor(String value) {
    final candidate = Uri.tryParse(value);
    final source = candidate?.host.isNotEmpty == true
        ? candidate!.host + candidate.path
        : path.basename(value);
    final slug = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return 'inspection';
    return slug.length > 64 ? slug.substring(0, 64) : slug;
  }

  static String _escape(Object? value) {
    return const HtmlEscape().convert(value?.toString() ?? '');
  }
}
