import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/shared_content_manager.dart';

void main() {
  group('Type Conversion Tests', () {
    
    test('Should convert Map<Object?, Object?> to Map<String, dynamic>', () {
      // Simulate the data format that comes from iOS method channel
      final nativeData = <Object?, Object?>{
        'type': 'file',
        'filePath': '/Users/test/file.html',
        'fileName': 'file.html'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(nativeData);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'file');
      expect(converted['filePath'], '/Users/test/file.html');
      expect(converted['fileName'], 'file.html');
    });

    test('Should handle already correct Map<String, dynamic>', () {
      // Test data that's already in the correct format
      final correctData = <String, dynamic>{
        'type': 'url',
        'content': 'https://example.com'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(correctData);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'url');
      expect(converted['content'], 'https://example.com');
    });

    test('Should handle null arguments', () {
      final converted = SharedContentManager.convertToStringDynamicMap(null);
      expect(converted, isNull);
    });

    test('Should handle non-Map arguments', () {
      final converted1 = SharedContentManager.convertToStringDynamicMap('string');
      expect(converted1, isNull);
      
      final converted2 = SharedContentManager.convertToStringDynamicMap(123);
      expect(converted2, isNull);
      
      final converted3 = SharedContentManager.convertToStringDynamicMap(['list']);
      expect(converted3, isNull);
    });

    test('Should handle non-string keys in Map', () {
      // Simulate data with non-string keys (though this shouldn't happen from iOS)
      final mixedKeyData = <Object?, Object?>{
        'type': 'file',
        123: 'numeric_key',
        'filePath': '/Users/test/file.html'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(mixedKeyData);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'file');
      expect(converted['123'], 'numeric_key'); // Key converted to string
      expect(converted['filePath'], '/Users/test/file.html');
    });

    test('Should handle complex iOS shared data', () {
      // Test the actual format that might come from iOS
      final iosData = <Object?, Object?>{
        'type': 'file',
        'filePath': '/Users/wouter/Library/Developer/CoreSimulator/Devices/2C19D11B-BEF5-45B1-81FD-0919B6BFB505/data/Containers/Data/Application/DDE7D1D9-790B-429E-A07B-BCAE79AADB4F/tmp/info.wouter.sourceviewer-Inbox/sample.py',
        'fileName': 'sample.py'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(iosData);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'file');
      expect(converted['fileName'], 'sample.py');
      expect(converted['filePath'], contains('sample.py'));
    });

    test('Should handle URL type with file path', () {
      // Test the case where iOS sends type: url but content is a file path
      final urlWithFilePath = <Object?, Object?>{
        'type': 'url',
        'content': 'file:///Users/test/file.html'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(urlWithFilePath);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'url');
      expect(converted['content'], 'file:///Users/test/file.html');
    });

    test('Should handle empty Map', () {
      final emptyData = <Object?, Object?>{};
      
      final converted = SharedContentManager.convertToStringDynamicMap(emptyData);
      
      expect(converted, isNotNull);
      expect(converted!.isEmpty, true);
    });

    test('Should handle Map with null values', () {
      final dataWithNulls = <Object?, Object?>{
        'type': 'file',
        'filePath': null,
        'fileName': 'file.html'
      };
      
      final converted = SharedContentManager.convertToStringDynamicMap(dataWithNulls);
      
      expect(converted, isNotNull);
      expect(converted!['type'], 'file');
      expect(converted['filePath'], isNull);
      expect(converted['fileName'], 'file.html');
    });

  });
}