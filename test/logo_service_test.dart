import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/logo_service.dart';

void main() {
  test('resolves logo domains for technologies, services and trackers', () {
    expect(logoDomainFor('WordPress'), 'wordpress.org');
    expect(logoDomainFor('Bootstrap 5.3'), 'getbootstrap.com');
    expect(logoDomainFor('Google Fonts'), 'www.google.com');
    expect(logoDomainFor('Facebook Pixel'), 'facebook.com');
    expect(logoDomainFor('Google Analytics'), 'marketingplatform.google.com');
    expect(logoDomainFor('Some Unknown Thing'), isNull);
  });
}
