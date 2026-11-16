import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/utils/app_version.dart';

void main() {
  test('kAppVersion matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line, startsWith('version: $kAppVersion+'));
  });

  test('the user agent carries the app version', () {
    expect(kServerUserAgent, contains('ViewSourceVibe/$kAppVersion '));
  });
}
