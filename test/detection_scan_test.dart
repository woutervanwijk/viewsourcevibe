// Runs detection over saved pages to review false positives by hand:
//   SITES=/path/to/pages flutter test test/detection_scan_test.dart
// Each `<host>.html` (with optional `<host>.headers`, raw `curl -D` output) is
// scanned; the report is written to `$SITES/detections.txt`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

void main() {
  final sites = Platform.environment['SITES'];

  test('scan saved pages', () async {
    final out = StringBuffer();
    final files = Directory(sites!)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.html'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final html = file.readAsStringSync();
      final name = file.uri.pathSegments.last.replaceAll('.html', '');
      final url = 'https://${name.split('_').first}/';
      final headers = <String, String>{};
      final headerFile = File(file.path.replaceAll('.html', '.headers'));
      if (headerFile.existsSync()) {
        for (final line in headerFile.readAsLinesSync()) {
          final i = line.indexOf(':');
          if (i > 0) {
            headers[line.substring(0, i).toLowerCase()] =
                line.substring(i + 1).trim();
          }
        }
      }
      final metadata =
          await extractMetadataInIsolate(html, url, headers: headers);
      out.writeln('=== $name');
      for (final d in detect(
        pageUrl: url,
        html: html,
        source: Detection.listFrom(metadata['detections']),
        requests: collectResourceUrls(metadata, const []),
      )) {
        final e = d.evidence.firstOrNull;
        final detail =
            (e?.detail ?? e?.title ?? '').replaceAll(RegExp(r'\s+'), ' ');
        out.writeln('  ${d.category.label}: ${d.name}'
            '${d.version != null ? ' ${d.version}' : ''}'
            '${d.hintOnly ? ' [hint]' : ''}  <- '
            '${detail.length > 120 ? detail.substring(0, 120) : detail}');
      }
    }
    File('$sites/detections.txt').writeAsStringSync(out.toString());
  }, skip: sites == null, timeout: const Timeout(Duration(minutes: 5)));
}
