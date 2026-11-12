import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/main.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// Records which load entry point was used instead of doing real work.
class _RecordingHtmlService extends HtmlService {
  final List<String> loadedUrls = [];
  final List<HtmlFile> loadedFiles = [];

  @override
  Future<void> loadFromUrl(
    String url, {
    int? switchToTab,
    bool skipWebViewLoad = false,
    bool forceReload = false,
  }) async {
    loadedUrls.add(url);
  }

  @override
  Future<void> loadFile(
    HtmlFile file, {
    bool clearProbe = true,
    bool isPartial = false,
    int? switchToTab,
    FileSnapshot? snapshot,
  }) async {
    loadedFiles.add(file);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('handleDeepLink text scheme', () {
    test('text that is entirely one URL is loaded as a URL, not as text',
        () async {
      final service = _RecordingHtmlService();
      await handleDeepLink(
        Uri.parse('viewsourcevibe://text?content=https%3A%2F%2Fexample.com'),
        service,
      );
      expect(service.loadedUrls, ['https://example.com']);
      expect(service.loadedFiles, isEmpty);
    });

    test('URL with query string survives encoding and loads in full',
        () async {
      final service = _RecordingHtmlService();
      // Strictly percent-encoded by the share extension: '&' and '=' in the
      // shared URL must not be parsed as query separators of the deep link.
      await handleDeepLink(
        Uri.parse(
            'viewsourcevibe://text?content=https%3A%2F%2Fexample.com%2F%3Fa%3D1%26b%3D2'),
        service,
      );
      expect(service.loadedUrls, ['https://example.com/?a=1&b=2']);
      expect(service.loadedFiles, isEmpty);
    });

    test('plain text is still loaded as a file', () async {
      final service = _RecordingHtmlService();
      await handleDeepLink(
        Uri.parse('viewsourcevibe://text?content=Hello%20World'),
        service,
      );
      expect(service.loadedUrls, isEmpty);
      expect(service.loadedFiles, hasLength(1));
    });

    test('text that merely contains a URL stays text content', () async {
      final service = _RecordingHtmlService();
      await handleDeepLink(
        Uri.parse(
            'viewsourcevibe://text?content=Check%20https%3A%2F%2Fexample.com%20out'),
        service,
      );
      expect(service.loadedUrls, isEmpty);
      expect(service.loadedFiles, hasLength(1));
    });
  });

  group('handleDeepLink open scheme', () {
    test('open?url= loads the URL including query string', () async {
      final service = _RecordingHtmlService();
      await handleDeepLink(
        Uri.parse(
            'viewsourcevibe://open?url=https%3A%2F%2Fexample.com%2F%3Fp%3D1%26q%3D2'),
        service,
      );
      expect(service.loadedUrls, ['https://example.com/?p=1&q=2']);
      expect(service.loadedFiles, isEmpty);
    });
  });

  group('handleDeepLink web URLs', () {
    test('http(s) URLs are loaded directly', () async {
      final service = _RecordingHtmlService();
      await handleDeepLink(Uri.parse('https://example.com/page'), service);
      expect(service.loadedUrls, ['https://example.com/page']);
      expect(service.loadedFiles, isEmpty);
    });
  });
}
