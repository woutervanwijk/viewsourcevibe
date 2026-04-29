import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InspectionExportService', () {
    test('builds a portable inspection zip with report and data files',
        () async {
      final htmlService = HtmlService();
      await htmlService.loadFile(
        HtmlFile(
          name: 'example.html',
          path: 'https://example.com',
          content:
              '<!doctype html><html><head><title>Example</title></head><body>Hello</body></html>',
          lastModified: DateTime.utc(2026, 4, 29),
          size: 82,
          isUrl: true,
          probeResult: {
            'url': 'https://example.com',
            'statusCode': 200,
            'headers': {'content-type': 'text/html'},
            'security': {'X-Content-Type-Options': 'nosniff'},
            'analyzedCookies': [],
          },
        ),
      );

      final bytes = InspectionExportService().buildPackageBytes(htmlService);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toSet();

      expect(names, contains('manifest.json'));
      expect(names, contains('report.html'));
      expect(names, contains('source/browser-dom.html'));
      expect(names, contains('network/headers.json'));
      expect(names, contains('analysis/security-scorecard.json'));

      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
      ) as Map<String, dynamic>;
      expect(manifest['format'], 'view-source-vibe-inspection-package');
      expect(manifest['source']['path'], 'https://example.com');
    });
  });
}
