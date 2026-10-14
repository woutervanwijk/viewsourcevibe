import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/detection/engine.dart';

import 'detection_helpers.dart';

List<String> names(String html, {String url = 'https://example.com/'}) =>
    [for (final d in detect(pageUrl: url, html: html)) d.name];

void main() {
  group('requests and cookies', () {
    test('groups per service and ignores first party', () {
      final ds = detect(
        pageUrl: 'https://www.example.com/',
        requests: [
          'https://www.google-analytics.com/g/collect?v=2',
          'https://www.google-analytics.com/analytics.js',
          'https://static.hotjar.com/c/hotjar.js',
          'https://cdn.example.com/app.js',
          'data:image/png;base64,AAAA',
        ],
        cookies: [
          {
            'name': '_ga',
            'category': 'analytics',
            'provider': 'Google Analytics'
          },
          {'name': 'sess', 'category': 'essential', 'provider': 'Shopify'},
        ],
      );
      expect(ds.map((d) => d.name), ['Hotjar', 'Google Analytics']);
      final ga = ds.last;
      expect(ga.requests, 2);
      expect(ga.cookies, {'_ga'});
    });

    test('tells gtag.js for Ads, Analytics and first-party GTM apart', () {
      final ds = detect(pageUrl: 'https://shop.nl/', requests: [
        'https://www.googletagmanager.com/gtag/js?id=AW-123456789',
        'https://www.googletagmanager.com/gtag/js?id=G-ABC',
        'https://shop.nl/metrics/gtm.js?id=GTM-ABC123',
      ]);
      expect(ds.map((d) => d.name),
          ['Google Ads', 'Google Analytics', 'Google Tag Manager']);
    });

    test('generic first-party cookie names are not ad trackers', () {
      final ds = detect(pageUrl: 'https://example.com/', cookies: [
        {'name': 'token', 'category': 'advertising', 'provider': 'Adform'},
        {'name': 'A', 'category': 'advertising', 'provider': 'Google'},
        {'name': 'visitor', 'category': 'advertising', 'provider': 'Nativo'},
        {'name': 'xyz_uid', 'category': 'advertising', 'provider': 'SomeAdCo'},
      ]);
      expect(ds.map((d) => d.name), ['SomeAdCo']);
    });

    test('a site is not its own tracker', () {
      final ds = detect(
          pageUrl: 'https://www.instagram.com/',
          requests: ['https://static.cdninstagram.com/app.js']);
      expect(ds, isEmpty);
    });
  });

  group('page source', () {
    test('finds trackers in scripts, tags and noscript pixels', () {
      expect(
          names('<script src="https://connect.facebook.net/en_US/fbevents.js">'
              '</script><iframe src="https://www.youtube.com/embed/x"></iframe>'
              '<img src="https://sb.scorecardresearch.com/p?c1=2">'),
          ['Meta Pixel', 'YouTube', 'Comscore']);
    });

    test('a preconnect is only a hint', () {
      final d = detect(
              html:
                  '<link rel="preconnect" href="https://fonts.googleapis.com">')
          .single;
      expect(d.name, 'Google Fonts');
      expect(d.hintOnly, isTrue);
    });

    test('ignores comments, visible text, links and profile data', () {
      expect(names('''
<!-- <script src="https://www.google-analytics.com/analytics.js"></script> -->
<p>doubleclick.net and https://www.hotjar.com set cookies</p>
<a href="https://vercel.com/?utm_source=x">Vercel</a>
<link rel="canonical" href="https://www.salesforce.com/">
<script type="application/ld+json">{"sameAs":["https://www.facebook.com/x"]}</script>
<script>window.__data=([1,"{\\"href\\":\\"https://x.com/acme\\",\\"sameAs\\":[\\"https://www.linkedin.com/company/acme\\"]}"])</script>
<script>{"uris":["dms.netmng.com","doubleclick.net"]}</script>
'''), isEmpty);
    });

    test('regressions: look-alike strings are not services', () {
      expect(names('''
<link rel="alternate" hreflang="uk-UA" href="https://example.com/ua/">
<a href="/druk-verhogen">x</a>
<figcaption>Graeme Sloan</figcaption>
<button class="Box-btn-octicon btn-octicon">x</button>
<div style="--flexbox-align-items-lg:flex-end"></div>
<style>.nes-page-intro.is-primary-alt{}</style>
<script>_.hj("HEAD");gtag('consent','default',{});const x={name:"Next.MetadataOutlet",m:t.media};</script>
<link rel="canonical" href="https://www.workforce.com/">
''', url: 'https://www.workforce.com/'), isEmpty);
    });

    test('a script URL in JSON config counts when assigned to src', () {
      expect(
          names('<script>window.cfg={"APS_SRC":"//c.aps.amazon-adsystem.com",'
              '"PIANO_HOST":"//experience.piano.io/xbuilder/experience/load?aid="}'
              '</script>'),
          ['Amazon Ads', 'Piano']);
    });

    test('an Instagram embed is Instagram, not the Meta Pixel', () {
      expect(
          names(
              '<iframe src="https://www.instagram.com/p/abc/embed"></iframe>'),
          ['Instagram']);
    });
  });

  group('technologies', () {
    test('versions, plugins and summaries', () {
      final ds = detect(
        html: '<meta name="generator" content="WordPress 6.5">'
            '<!-- This site is optimized with the Yoast SEO plugin -->'
            '<script src="/wp-includes/js/jquery/jquery.min.js?ver=3.7.1"></script>'
            '<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>',
        headers: {'server': 'nginx/1.25.3', 'x-powered-by': 'PHP/8.2.1'},
      );
      final tech = techSummary(ds);
      expect(tech['CMS'], 'WordPress');
      expect(tech['WordPress Version'], '6.5');
      expect(tech['Plugins'], 'Yoast SEO');
      expect(tech['Library'], 'jQuery');
      expect(tech['Web Server'], 'Nginx');
      expect(tech['Nginx Version'], '1.25.3');
      expect(tech['Backend'], 'PHP');
    });

    test('plugins need their CMS', () {
      expect(names('<div class="elementor-section"></div>'), isEmpty);
    });
  });

  test('logos and origins come from the catalogue', () {
    expect(logoDomainFor('Facebook Pixel'), 'facebook.com');
    expect(logoDomainFor('Bootstrap 5.3'), 'getbootstrap.com');
    expect(vendorOriginFor('Simple Analytics'), 'NL');
    expect(entityForHost('analytics.tiktok.com')?.name, 'TikTok Pixel');
    expect(entityForHost('www.tiktok.com')?.name, 'TikTok');
  });
}
