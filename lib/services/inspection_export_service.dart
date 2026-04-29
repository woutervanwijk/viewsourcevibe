import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/file_system_service.dart';
import 'package:view_source_vibe/services/html_service.dart';

class InspectionExportService {
  static const int packageFormatVersion = 1;

  Future<File> exportCurrentInspection(HtmlService htmlService) async {
    final currentFile = htmlService.currentFile;
    if (currentFile == null) {
      throw StateError('No file or URL loaded');
    }

    final bytes = buildPackageBytes(htmlService);
    final fileSystem = FileSystemService();
    final filename = buildPackageFilename(currentFile);

    return fileSystem.saveBinaryToDownloadsDirectory(
      filename: filename,
      bytes: bytes,
      subDirectory: 'inspection-packages',
    );
  }

  Future<File> createShareableInspectionPackage(HtmlService htmlService) async {
    final currentFile = htmlService.currentFile;
    if (currentFile == null) {
      throw StateError('No file or URL loaded');
    }

    return FileSystemService().saveBinaryToTempFile(
      filename: buildPackageFilename(currentFile),
      bytes: buildPackageBytes(htmlService),
    );
  }

  List<int> buildPackageBytes(HtmlService htmlService) {
    final currentFile = htmlService.currentFile;
    if (currentFile == null) {
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

    final manifest = _buildManifest(currentFile, exportedAt);
    final probe = htmlService.probeResult;
    final browserProbe = htmlService.browserProbeResult;
    final metadata = htmlService.pageMetadata;
    final timeline = htmlService.resourceTimelineData;
    final serverSource = htmlService.serverSource;
    final browserSource = currentFile.content;
    final diff = _lineDiff(serverSource, browserSource);

    addJson('manifest.json', manifest);
    addString(
      'report.html',
      _buildHtmlReport(
        manifest: manifest,
        currentFile: currentFile,
        probe: probe,
        browserProbe: browserProbe,
        metadata: metadata,
        timeline: timeline,
        hasServerSource: serverSource?.isNotEmpty == true,
        hasBrowserSource: browserSource.isNotEmpty,
      ),
    );

    addString('source/browser-dom.html', browserSource);
    if (serverSource?.isNotEmpty == true) {
      addString('source/server.html', serverSource!);
    }
    if (diff.isNotEmpty) {
      addString('source/diff.patch', diff);
    }

    addJson('network/probe.json', probe ?? {});
    addJson('network/browser-probe.json', browserProbe ?? {});
    addJson('network/headers.json', _headersFrom(probe));
    addJson('network/cookies.json', probe?['analyzedCookies'] ?? []);
    addJson('network/redirects.json', _redirectsFrom(probe));
    addJson('network/timeline.json', timeline);

    addJson('analysis/metadata.json', metadata ?? {});
    addJson('analysis/security-scorecard.json', probe?['security'] ?? {});
    addJson('analysis/certificate.json', probe?['certificate'] ?? {});
    addJson('analysis/robots-sitemap.json', probe?['robotsSitemap'] ?? {});
    addJson('analysis/structured-data.json', metadata?['structuredData'] ?? []);
    addJson('analysis/page-weight.json',
        browserProbe?['pageWeight'] ?? metadata?['pageWeight'] ?? {});

    return ZipEncoder().encode(archive);
  }

  static String buildPackageFilename(HtmlFile file) {
    final source = file.isUrl && file.path.isNotEmpty ? file.path : file.name;
    final slug = _slugFor(source);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_')
        .replaceFirst(RegExp(r'Z$'), 'Z');
    return 'viewsourcevibe-$slug-$stamp.zip';
  }

  static Map<String, dynamic> _buildManifest(HtmlFile file, String exportedAt) {
    return {
      'format': 'view-source-vibe-inspection-package',
      'formatVersion': packageFormatVersion,
      'exportedAt': exportedAt,
      'source': {
        'name': file.name,
        'path': file.path,
        'isUrl': file.isUrl,
        'size': file.size,
        'lastModified': file.lastModified.toUtc().toIso8601String(),
      },
    };
  }

  static Map<String, dynamic> _headersFrom(Map<String, dynamic>? probe) {
    final headers = probe?['headers'];
    if (headers is Map) return Map<String, dynamic>.from(headers);
    return {};
  }

  static List<dynamic> _redirectsFrom(Map<String, dynamic>? probe) {
    final chain = probe?['redirectChain'];
    if (chain is List) return chain;
    final location = probe?['redirectLocation']?.toString();
    if (location == null || location.isEmpty) return [];
    return [
      {
        'from': probe?['url'],
        'to': location,
        'statusCode': probe?['statusCode'],
        'reasonPhrase': probe?['reasonPhrase'],
      }
    ];
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

  static String _buildHtmlReport({
    required Map<String, dynamic> manifest,
    required HtmlFile currentFile,
    required Map<String, dynamic>? probe,
    required Map<String, dynamic>? browserProbe,
    required Map<String, dynamic>? metadata,
    required List<Map<String, dynamic>> timeline,
    required bool hasServerSource,
    required bool hasBrowserSource,
  }) {
    final headers = _headersFrom(probe);
    final security = probe?['security'] is Map
        ? Map<String, dynamic>.from(probe!['security'])
        : <String, dynamic>{};
    final cookies = probe?['analyzedCookies'] is List
        ? probe!['analyzedCookies'] as List
        : const [];
    final redirects = _redirectsFrom(probe);
    final pageWeight =
        browserProbe?['pageWeight'] ?? metadata?['pageWeight'] ?? {};

    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>View Source Vibe Inspection</title>
  <style>
    body { margin: 0; font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #1f2937; background: #f8fafc; }
    main { max-width: 1040px; margin: 0 auto; padding: 32px 20px 48px; }
    h1 { margin: 0 0 6px; font-size: 28px; }
    h2 { margin: 28px 0 12px; font-size: 18px; }
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
  </style>
</head>
<body>
<main>
  <h1>Inspection Package</h1>
  <p class="muted">Exported ${_escape(manifest['exportedAt'])} by View Source Vibe.</p>

  <section class="grid">
    ${_metricCard('Target', currentFile.isUrl ? currentFile.path : currentFile.name)}
    ${_metricCard('Type', currentFile.isUrl ? 'URL' : 'Local file')}
    ${_metricCard('Size', '${currentFile.size} bytes')}
    ${_metricCard('HTTP status', probe?['statusCode']?.toString() ?? 'N/A')}
  </section>

  <h2>Included Files</h2>
  <div class="card">
    ${_pill('manifest.json')}
    ${_pill('report.html')}
    ${_pill('source/browser-dom.html', enabled: hasBrowserSource)}
    ${_pill('source/server.html', enabled: hasServerSource)}
    ${_pill('source/diff.patch', enabled: hasServerSource)}
    ${_pill('network/*.json')}
    ${_pill('analysis/*.json')}
  </div>

  <h2>Page Summary</h2>
  <section class="grid">
    ${_metricCard('Title', metadata?['title']?.toString() ?? 'N/A')}
    ${_metricCard('Description', metadata?['description']?.toString() ?? 'N/A')}
    ${_metricCard('Resources', timeline.length.toString())}
    ${_metricCard('Cookies', cookies.length.toString())}
    ${_metricCard('Redirects', redirects.length.toString())}
    ${_metricCard('Page weight', _pageWeightLabel(pageWeight))}
  </section>

  <h2>Headers</h2>
  ${_table(headers.entries.map((entry) => [
              entry.key,
              entry.value?.toString() ?? ''
            ]).toList(), ['Header', 'Value'])}

  <h2>Security Headers</h2>
  ${_table(security.entries.map((entry) => [
              entry.key,
              entry.value?.toString() ?? 'Missing'
            ]).toList(), ['Header', 'Value'])}

  <h2>Redirect Chain</h2>
  ${_table(redirects.map((item) {
              final map = item is Map ? item : {};
              return [
                map['statusCode']?.toString() ?? '',
                map['from']?.toString() ?? '',
                map['to']?.toString() ?? '',
              ];
            }).toList(), ['Status', 'From', 'To'])}

  <h2>Largest Timeline Entries</h2>
  ${_table(_timelineRows(timeline), ['Type', 'URL', 'Transfer', 'Decoded'])}
</main>
</body>
</html>''';
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

  static List<List<String>> _timelineRows(List<Map<String, dynamic>> timeline) {
    final rows = List<Map<String, dynamic>>.from(timeline);
    rows.sort((a, b) {
      final aSize = (a['decoded'] as num?)?.toInt() ??
          (a['transfer'] as num?)?.toInt() ??
          0;
      final bSize = (b['decoded'] as num?)?.toInt() ??
          (b['transfer'] as num?)?.toInt() ??
          0;
      return bSize.compareTo(aSize);
    });
    return rows.take(12).map((item) {
      return [
        item['type']?.toString() ?? '',
        item['name']?.toString() ?? item['url']?.toString() ?? '',
        item['transfer']?.toString() ?? '0',
        item['decoded']?.toString() ?? '0',
      ];
    }).toList();
  }

  static String _pageWeightLabel(Object? pageWeight) {
    if (pageWeight is! Map) return 'N/A';
    final decoded = pageWeight['totalDecoded'] ?? pageWeight['decoded'];
    final transfer = pageWeight['totalTransfer'] ?? pageWeight['transfer'];
    if (decoded == null && transfer == null) return 'N/A';
    return 'transfer ${transfer ?? 0} bytes, decoded ${decoded ?? 0} bytes';
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
