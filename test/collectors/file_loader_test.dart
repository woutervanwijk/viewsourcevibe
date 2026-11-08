import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/collectors/file_loader.dart';

class _MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory root = Directory.systemTemp.createTempSync('vsv_fileloader');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '${root.path}/Documents';
  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/Support';
  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';
  @override
  Future<String?> getDownloadsPath() async => '${root.path}/Downloads';
}

const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPathProvider mock;
  late Directory docs;
  late Directory outside;

  setUpAll(() {
    mock = _MockPathProvider();
    PathProviderPlatform.instance = mock;
    for (final d in ['Documents', 'Support', 'tmp', 'Downloads']) {
      Directory('${mock.root.path}/$d').createSync(recursive: true);
    }
    docs = Directory('${mock.root.path}/Documents');
    outside = Directory.systemTemp.createTempSync('vsv_outside');
  });

  group('fromPath', () {
    test('Latin-1 file decodes correctly instead of throwing (B14)', () async {
      final f = File('${docs.path}/latin1.html')
        ..writeAsBytesSync(
            latin1.encode('<meta charset="iso-8859-1"><p>café ü</p>'));
      final s = await FileLoader.fromPath(f.path, origin: FileOrigin.restore);
      expect(s.text.text, contains('café ü'));
      expect(s.text.hadMalformed, isFalse);
      expect(s.isBinary, isFalse);
    });

    test('byteLength is bytes, not characters', () async {
      final f = File('${docs.path}/utf8.txt')
        ..writeAsBytesSync(utf8.encode('héllo \u{1F600}'));
      final s = await FileLoader.fromPath(f.path, origin: FileOrigin.restore);
      expect(s.byteLength, utf8.encode('héllo \u{1F600}').length);
      expect(s.toHtmlFile().size, s.byteLength);
      expect(s.toHtmlFile().size, isNot(s.text.text.length));
    });

    test('lastModified is Present(measured, file) for a real path', () async {
      final f = File('${docs.path}/a.txt')..writeAsStringSync('x');
      final s = await FileLoader.fromPath(f.path, origin: FileOrigin.deepLink);
      final lm = s.lastModified;
      expect(lm, isA<Present<DateTime>>());
      lm as Present<DateTime>;
      expect(lm.source, DataSource.file);
      expect(lm.provenance, Provenance.measured);
      expect(lm.value, f.lastModifiedSync());
      expect(s.name, 'a.txt');
      expect(s.path, f.path);
      expect(s.origin, FileOrigin.deepLink);
    });

    test('PNG is binary, keeps bytes, is media; adapter content is empty',
        () async {
      final f = File('${docs.path}/pic.png')..writeAsBytesSync(_png);
      final s = await FileLoader.fromPath(f.path, origin: FileOrigin.restore);
      expect(s.isBinary, isTrue);
      expect(s.isMedia, isTrue);
      expect(s.bytes, _png);
      final h = s.toHtmlFile();
      expect(h.content, '');
      expect(h.size, _png.length);
      expect(h.isMedia, isTrue);
    });

    test('path outside app directories is refused when sandbox enforced (B31)',
        () async {
      final f = File('${outside.path}/secret.txt')..writeAsStringSync('s');
      expect(
        FileLoader.fromPath(f.path, origin: FileOrigin.share),
        throwsA(isA<FileLoadException>()
            .having((e) => e.outsideSandbox, 'outsideSandbox', isTrue)),
      );
    });

    test('restore may read outside app directories with enforceSandbox: false',
        () async {
      final f = File('${outside.path}/trusted.txt')..writeAsStringSync('ok');
      final s = await FileLoader.fromPath(f.path,
          origin: FileOrigin.restore, enforceSandbox: false);
      expect(s.text.text, 'ok');
    });

    test('missing file throws FileLoadException', () async {
      expect(
        FileLoader.fromPath('${docs.path}/nope.txt', origin: FileOrigin.share),
        throwsA(isA<FileLoadException>()
            .having((e) => e.notFound, 'notFound', isTrue)),
      );
    });
  });

  group('share from Android shared storage (R16)', () {
    tearDown(() => FileLoader.isAndroid = () => false);

    // Nonexistent files: accepted means "got past the sandbox", i.e. notFound.
    Matcher accepted() => throwsA(isA<FileLoadException>()
        .having((e) => e.outsideSandbox, 'outsideSandbox', isFalse)
        .having((e) => e.notFound, 'notFound', isTrue));
    Matcher refused() => throwsA(isA<FileLoadException>()
        .having((e) => e.outsideSandbox, 'outsideSandbox', isTrue));

    test('accepted for share on Android', () async {
      FileLoader.isAndroid = () => true;
      await expectLater(
          FileLoader.fromPath('/storage/emulated/0/Download/x.html',
              origin: FileOrigin.share),
          accepted());
      await expectLater(
          FileLoader.fromPath('/sdcard/x.html', origin: FileOrigin.share),
          accepted());
    });

    test('refused elsewhere on Android, and traversal', () async {
      FileLoader.isAndroid = () => true;
      for (final bad in [
        '/data/data/other.app/files/x.html',
        '/etc/passwd',
        '/storage/emulated/0/../../data/x',
      ]) {
        await expectLater(
            FileLoader.fromPath(bad, origin: FileOrigin.share), refused(),
            reason: bad);
      }
    });

    test('not allowed off Android, nor for deep links', () async {
      FileLoader.isAndroid = () => false;
      await expectLater(
          FileLoader.fromPath('/storage/emulated/0/x.html',
              origin: FileOrigin.share),
          refused());
      FileLoader.isAndroid = () => true;
      await expectLater(
          FileLoader.fromPath('/storage/emulated/0/x.html',
              origin: FileOrigin.deepLink),
          refused());
    });
  });

  group('fromDeepLinkPath', () {
    test('outside path becomes a visible isError file', () async {
      final f = File('${outside.path}/secret.txt')..writeAsStringSync('s');
      final s = await FileLoader.fromDeepLinkPath(f.path);
      expect(s.isError, isTrue);
      expect(s.text.text,
          "File outside the app's folders was not opened: secret.txt");
      expect(s.toHtmlFile().isError, isTrue);
    });

    test('missing file becomes "File not found"', () async {
      final s = await FileLoader.fromDeepLinkPath('${docs.path}/gone.html');
      expect(s.isError, isTrue);
      expect(s.text.text, 'File not found: gone.html');
    });

    test('good file loads normally', () async {
      final f = File('${docs.path}/ok.html')..writeAsStringSync('<p>');
      final s = await FileLoader.fromDeepLinkPath(f.path);
      expect(s.isError, isFalse);
      expect(s.text.text, '<p>');
    });
  });

  group('fromBytes', () {
    test('shared UTF-8 bytes decode correctly (not fromCharCodes)', () {
      final bytes = utf8.encode('<p>héllo €</p>');
      final s =
          FileLoader.fromBytes(bytes, name: 'x.html', origin: FileOrigin.share);
      expect(s.text.text, '<p>héllo €</p>');
      expect(s.byteLength, bytes.length);
      expect(s.toHtmlFile().isShared, isTrue);
    });

    test('picker/share lastModified is Unavailable(notReportedByPlatform)', () {
      for (final o in [FileOrigin.picker, FileOrigin.share]) {
        final s = FileLoader.fromBytes([65], name: 'a.txt', origin: o);
        final lm = s.lastModified;
        expect(lm, isA<Unavailable<DateTime>>());
        expect((lm as Unavailable<DateTime>).reason,
            UnavailableReason.notReportedByPlatform);
      }
    });

    test('adapter uses now() only as a placeholder when unavailable', () {
      final before = DateTime.now();
      final h =
          FileLoader.fromBytes([65], name: 'a.txt', origin: FileOrigin.picker)
              .toHtmlFile();
      expect(h.lastModified.isBefore(before), isFalse);
    });

    test('PNG bytes are binary', () {
      final s =
          FileLoader.fromBytes(_png, name: 'p.png', origin: FileOrigin.picker);
      expect(s.isBinary, isTrue);
      expect(s.isMedia, isTrue);
    });
  });

  group('fromText', () {
    test('text is kept verbatim with UTF-8 byte length and no extension', () {
      final s = FileLoader.fromText('hé', origin: FileOrigin.share);
      expect(s.text.text, 'hé');
      expect(s.byteLength, 3);
      expect(s.lastModified, isA<Unavailable<DateTime>>());
      expect(s.name, 'Shared text');
      expect(s.toHtmlFile().extension, '');
      expect(s.toHtmlFile().isShared, isTrue);
    });

    test('isError carries to the adapter (content:// error page)', () {
      final s = FileLoader.fromText('boom',
          origin: FileOrigin.deepLink,
          name: 'Content File Error',
          path: 'content://x/y',
          isError: true);
      expect(s.isError, isTrue);
      final h = s.toHtmlFile();
      expect(h.isError, isTrue);
      expect(h.isShared, isFalse);
      expect(h.path, 'content://x/y');
    });
  });

  group('HtmlFile.extension (B37)', () {
    test('name without a dot has an empty extension', () {
      expect(HtmlFile.fromContent('Shared text', 'x').extension, '');
      expect(HtmlFile.fromContent('a.HTML', 'x').extension, 'html');
    });
  });
}
