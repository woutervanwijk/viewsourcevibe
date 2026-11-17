import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/permissions_policy.dart';

void main() {
  test('permissions-policy', () {
    final p = parsePermissionsPolicy(
        'geolocation=(), camera=(self "https://a.test"), fullscreen=*, microphone=self');
    expect(
        p.features.keys, ['geolocation', 'camera', 'fullscreen', 'microphone']);
    expect(p.features['geolocation']!.none, isTrue);
    expect(p.features['camera']!.self, isTrue);
    expect(p.features['camera']!.origins, ['https://a.test']);
    expect(p.features['fullscreen']!.all, isTrue);
    expect(p.features['microphone']!.self, isTrue);
    expect(p.invalid, isEmpty);
  });
  test('a broken member does not lose the others', () {
    final p = parsePermissionsPolicy('camera=(self, geolocation=(), ,x');
    expect(p.features.keys, contains('geolocation'));
    expect(p.invalid, isNotEmpty);
  });
  test('repeated header values joined by a comma parse as one', () {
    expect(parsePermissionsPolicy('camera=(), microphone=()').features,
        hasLength(2));
  });
  test('iframe allow', () {
    final p = parseFeaturePolicy(
        "camera; microphone 'none'; geolocation https://m.test *",
        iframeAllow: true);
    expect(p.features['camera']!.src, isTrue);
    expect(p.features['microphone']!.none, isTrue);
    expect(p.features['geolocation']!.all, isTrue);
    expect(p.features['geolocation']!.origins, ['https://m.test']);
  });
  test('empty input', () {
    expect(parsePermissionsPolicy('').features, isEmpty);
    expect(parseFeaturePolicy('  ').features, isEmpty);
  });
  test('names are lower-cased, repeats keep the first', () {
    final p = parsePermissionsPolicy('Camera=(), camera=*');
    expect(p.features.keys, ['camera']);
    expect(p.features['camera']!.none, isTrue);
    expect(p.invalid, ['camera (repeated)']);
  });
  test('quoted self is not a keyword; params and commas in strings', () {
    final p = parsePermissionsPolicy(
        'camera=("self"), mic=(self;x=1 "https://a.test,b"), usb=(self);report-to=x');
    expect(p.features.keys, ['mic', 'usb']);
    expect(p.features['mic']!.self, isTrue);
    expect(p.features['mic']!.origins, ['https://a.test,b']);
    expect(p.features['usb']!.self, isTrue);
    expect(p.invalid, hasLength(1));
  });
  test('feature-policy header defaults to self', () {
    final p = parseFeaturePolicy(
        "geolocation 'none'; camera 'self' https://a.test; fullscreen *; usb");
    expect(p.features['geolocation']!.none, isTrue);
    expect(p.features['camera']!.self, isTrue);
    expect(p.features['camera']!.origins, ['https://a.test']);
    expect(p.features['fullscreen']!.all, isTrue);
    expect(p.features['usb']!.self, isTrue);
    expect(p.features['usb']!.src, isFalse);
  });
}
