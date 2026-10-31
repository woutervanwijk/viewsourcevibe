import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:view_source_vibe/services/file_system_service.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory root = Directory.systemTemp.createTempSync('vsv_sandbox');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory('${root.path}/Documents').path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory('${root.path}/Support').path;

  @override
  Future<String?> getTemporaryPath() async =>
      Directory('${root.path}/tmp').path;

  @override
  Future<String?> getDownloadsPath() async =>
      Directory('${root.path}/Downloads').path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPathProviderPlatform mock;

  setUpAll(() {
    mock = MockPathProviderPlatform();
    PathProviderPlatform.instance = mock;
    for (final d in ['Documents', 'Support', 'tmp', 'Downloads']) {
      Directory('${mock.root.path}/$d').createSync(recursive: true);
    }
  });

  group('normalizeExternalFilePath', () {
    test('converts file:// URLs to absolute paths', () {
      expect(normalizeExternalFilePath('file:///tmp/a.html'), '/tmp/a.html');
      expect(normalizeExternalFilePath('file://localhost/tmp/a.html'),
          '/localhost/tmp/a.html');
    });

    test('rejects relative paths and NUL bytes', () {
      expect(normalizeExternalFilePath('relative/file.html'), isNull);
      expect(normalizeExternalFilePath('/tmp/a\u0000b'), isNull);
    });

    test('normalizes .. segments', () {
      expect(normalizeExternalFilePath('/tmp/../etc/passwd'), '/etc/passwd');
    });
  });

  group('resolveWithinAppDirectories', () {
    test('allows files inside app documents directory', () async {
      final resolved = await resolveWithinAppDirectories(
          'file://${mock.root.path}/Documents/page.html');
      expect(resolved, '${mock.root.path}/Documents/page.html');
    });

    test('blocks arbitrary system paths via deep link', () async {
      expect(await resolveWithinAppDirectories('/etc/passwd'), isNull);
      expect(
          await resolveWithinAppDirectories(
              'file:///etc/passwd'),
          isNull);
      expect(
          await resolveWithinAppDirectories(
              '${mock.root.path}/Documents/../../etc/passwd'),
          isNull);
      expect(
          await resolveWithinAppDirectories('/Users/x/.ssh/id_rsa'), isNull);
    });

    test('blocks sibling directory with similar prefix', () async {
      expect(
        await resolveWithinAppDirectories('${mock.root.path}/DocumentsEvil/x'),
        isNull,
      );
    });
  });
}
