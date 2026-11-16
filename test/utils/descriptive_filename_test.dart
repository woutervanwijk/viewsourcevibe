import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/descriptive_filename.dart';

void main() {
  test('uses the last meaningful path segment', () {
    expect(
        generateDescriptiveFilename(
            Uri.parse('https://example.com/a/app.js'), ''),
        'app.js');
  });

  test('falls back to the humanised domain', () {
    expect(
        generateDescriptiveFilename(Uri.parse('https://www.example.com/'), ''),
        'Example');
  });

  test('skips index and underscore segments and cleans characters', () {
    expect(
        generateDescriptiveFilename(
            Uri.parse('https://example.com/my page/index'), ''),
        'my-page');
  });
}
