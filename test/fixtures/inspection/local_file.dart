import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';

import 'package:view_source_vibe/utils/text_decoding.dart';

import 'builders.dart';

const localFileHtml =
    '<!doctype html><html><body>LOCAL-FILE-TEXT</body></html>';

FileSnapshot localFileSnapshot() => FileSnapshot(
      name: 'page.html',
      path: '/tmp/page.html',
      origin: FileOrigin.picker,
      bytes: localFileHtml.codeUnits,
      text: decoded(localFileHtml,
          charset: 'utf-8', source: CharsetSource.fallback, byteLength: 123),
      lastModified: const Unavailable(UnavailableReason.notApplicable),
    );

/// A local HTML file: no server, no browser, lastModified unknown.
PageInspection localFile() {
  final f = localFileSnapshot();
  return PageInspection(
    generation: 1,
    target: FileTarget(f),
    server: const Unavailable(UnavailableReason.notApplicable, 'local file'),
    browser: const Unavailable(UnavailableReason.notApplicable, 'local file'),
    file: file(f),
    robots: const Unavailable(UnavailableReason.notApplicable, 'local file'),
  );
}
