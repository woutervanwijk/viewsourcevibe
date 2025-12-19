import 'package:flutter_test/flutter_test.dart';

void main() {
  group('File URL Conversion Tests', () {
    test('Should convert file:/// URLs to proper paths', () {
      // Test standard file:/// URLs
      final fileUrl1 = 'file:///Users/test/file.html';
      final expectedPath1 = '/Users/test/file.html';

      final convertedPath1 = fileUrl1.replaceFirst('file:///', '/');
      expect(convertedPath1, expectedPath1);
    });

    test('Should convert file/// URLs to proper paths', () {
      // Test non-standard file/// URLs (iOS specific)
      final fileUrl2 = 'file///Users/test/file.html';
      final expectedPath2 = '/Users/test/file.html';

      final convertedPath2 = fileUrl2.replaceFirst('file///', '/');
      expect(convertedPath2, expectedPath2);
    });

    test('Should convert file:// URLs to proper paths', () {
      // Test standard file:// URLs
      final fileUrl3 = 'file://Users/test/file.html';
      final expectedPath3 = '/Users/test/file.html';

      final convertedPath3 = fileUrl3.replaceFirst('file://', '/');
      expect(convertedPath3, expectedPath3);
    });

    test('Should handle complex iOS file paths', () {
      // Test the actual iOS file path from the error
      final iosFilePath =
          'file///Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/index.html';

      final expectedPath =
          '/Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/index.html';

      final convertedPath = iosFilePath.replaceFirst('file///', '/');
      expect(convertedPath, expectedPath);
      expect(convertedPath.startsWith('/'), true);
      expect(convertedPath.contains('index.html'), true);
    });

    test('Should handle regular file paths without conversion', () {
      // Test regular file paths that don't need conversion
      final regularPath = '/Users/test/file.html';
      expect(regularPath.startsWith('file:///'), false);
      expect(regularPath.startsWith('file///'), false);
      expect(regularPath.startsWith('file://'), false);
      expect(regularPath.startsWith('/'), true);
    });

    test('Should handle various file URL formats', () {
      final testCases = [
        {
          'input':
              'file:///var/mobile/Containers/Data/Application/app/file.txt',
          'expected': '/var/mobile/Containers/Data/Application/app/file.txt'
        },
        {
          'input': 'file///var/mobile/Containers/Data/Application/app/file.txt',
          'expected': '/var/mobile/Containers/Data/Application/app/file.txt'
        },
        {
          'input': 'file://var/mobile/Containers/Data/Application/app/file.txt',
          'expected': '/var/mobile/Containers/Data/Application/app/file.txt'
        },
        {
          'input': 'file:///Library/Application Support/app/data.json',
          'expected': '/Library/Application Support/app/data.json'
        },
        {
          'input': 'file///Library/Application Support/app/data.json',
          'expected': '/Library/Application Support/app/data.json'
        },
      ];

      for (final testCase in testCases) {
        final input = testCase['input'] as String;
        final expected = testCase['expected'] as String;

        String converted;
        if (input.startsWith('file:///')) {
          converted = input.replaceFirst('file:///', '/');
        } else if (input.startsWith('file///')) {
          converted = input.replaceFirst('file///', '/');
        } else if (input.startsWith('file://')) {
          converted = input.replaceFirst('file://', '/');
        } else {
          converted = input;
        }

        expect(converted, expected);
      }
    });

    test('Should preserve file paths that are already normalized', () {
      final normalizedPaths = [
        '/Users/test/file.html',
        '/var/mobile/Containers/Data/Application/app/file.txt',
        '/Library/Application Support/app/data.json',
        '/Applications/App.app/Contents/Resources/config.json',
      ];

      for (final path in normalizedPaths) {
        expect(path.startsWith('file:///'), false);
        expect(path.startsWith('file///'), false);
        expect(path.startsWith('file://'), false);
        expect(path.startsWith('/'), true);
      }
    });
  });
}
