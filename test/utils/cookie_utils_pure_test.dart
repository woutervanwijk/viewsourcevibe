import 'package:view_source_vibe/utils/cookie_utils.dart';

void main() {
  print('Running CookieUtils Pure Tests...');

  void expect(dynamic actual, dynamic matcher, String reason) {
    if (actual != matcher) {
      throw Exception('Failed: $reason. Expected $matcher but got $actual');
    }
  }

  // 1. Google Analytics
  final ga = CookieUtils.analyze('_ga=GA1.2.123456789.123456789', 'Server');
  expect(ga.category, CookieCategory.analytics, '_ga category');
  expect(ga.provider, 'Google Analytics', '_ga provider');

  // 2. Google Ads
  final nid = CookieUtils.analyze('NID=12345', 'Server');
  expect(nid.category, CookieCategory.advertising, 'NID category');

  // 3. AWS
  final aws = CookieUtils.analyze('AWSALB=12345', 'Server');
  expect(aws.category, CookieCategory.functional, 'AWSALB category');

  // 4. Unknown
  final unknown = CookieUtils.analyze('my_random_cookie=1', 'Server');
  expect(unknown.category, CookieCategory.unknown, 'Unknown category');

  print('All pure tests passed!');
}
