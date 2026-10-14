import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/font_url.dart';

void main() {
  const adobe = 'https://use.typekit.net/af/5f7a1e/00000000000000007735a0f7/30/'
      'l?primer=7cdcb44be4a7db8877ffa5c0007b8dd865b3bbc383831fe2ea177f62257a9191'
      '&fvd=i7&v=3';

  test('recognises font files, including extensionless Adobe Fonts', () {
    expect(
        isFontUrl('https://fonts.gstatic.com/s/inter/v13/abc.woff2'), isTrue);
    expect(isFontUrl('https://example.com/fonts/Inter-Bold.ttf?v=2'), isTrue);
    expect(isFontUrl(adobe), isTrue);
    expect(isFontUrl('https://use.typekit.net/abc1def.css'), isFalse);
    expect(isFontUrl('https://p.typekit.net/p.css?s=1&k=abc'), isFalse);
    expect(isFontUrl('https://example.com/app.js'), isFalse);
  });

  test('describes fonts', () {
    expect(describeFontUrl('https://example.com/Inter-Bold.woff2'),
        ('Inter-Bold', 'WOFF2'));
    expect(describeFontUrl(adobe), ('Adobe Fonts · 700 italic', 'WOFF2'));
  });
}
