import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:view_source_vibe/services/tracker_detector.dart';

/// Fetches and caches service/tracker logos (in memory and on disk, 30 days).
///
/// Logos come from DuckDuckGo's favicon service, so the inspected site is
/// never contacted; DuckDuckGo only sees which service domains are displayed.
class LogoService {
  static const _maxAge = Duration(days: 30);
  static final Map<String, Future<Uint8List?>> _requests = {};
  static final Map<String, Uint8List> _loaded = {};

  /// Bytes already available without waiting, if any.
  static Uint8List? cached(String domain) => _loaded[domain];

  static Future<Uint8List?> load(String domain) =>
      _requests.putIfAbsent(domain, () => _fetch(domain));

  static Future<Uint8List?> _fetch(String domain) async {
    try {
      File? file;
      if (!kIsWeb) {
        try {
          final dir = await getApplicationCacheDirectory();
          file = File('${dir.path}/logos/$domain.img');
          if (await file.exists() &&
              DateTime.now().difference(await file.lastModified()) < _maxAge) {
            return _loaded[domain] = await file.readAsBytes();
          }
        } catch (_) {
          file = null; // no cache directory available: memory only
        }
      }

      final response = await http
          .get(Uri.parse('https://icons.duckduckgo.com/ip3/$domain.ico'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      if (file != null) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
      return _loaded[domain] = response.bodyBytes;
    } catch (e) {
      debugPrint('Logo fetch failed for $domain: $e');
      _requests.remove(domain); // allow a retry later
      return null;
    }
  }
}

const _techDomains = <String, String>{
  // CMS & platforms
  'wordpress': 'wordpress.org',
  'woocommerce': 'woocommerce.com',
  'shopify': 'shopify.com',
  'wix': 'wix.com',
  'squarespace': 'squarespace.com',
  'webflow': 'webflow.com',
  'drupal': 'drupal.org',
  'joomla': 'joomla.org',
  'magento': 'magento.com',
  'prestashop': 'prestashop.com',
  'bigcommerce': 'bigcommerce.com',
  'bigcartel': 'bigcartel.com',
  'typo3': 'typo3.org',
  'umbraco': 'umbraco.com',
  'strapi': 'strapi.io',
  'ghost': 'ghost.org',
  'contentful': 'contentful.com',
  'sitecore': 'sitecore.com',
  'adobe experience manager': 'adobe.com',
  '1c-bitrix': 'bitrix24.com',
  // Frameworks, libraries, servers
  'bootstrap': 'getbootstrap.com',
  'tailwind': 'tailwindcss.com',
  'bulma': 'bulma.io',
  'foundation': 'get.foundation',
  'chakra ui': 'chakra-ui.com',
  'material components': 'm3.material.io',
  'uikit': 'getuikit.com',
  'varnish': 'varnish-software.com',
  'angular': 'angular.dev',
  'next.js': 'nextjs.org',
  'nuxt': 'nuxt.com',
  'remix': 'remix.run',
  'sveltekit': 'svelte.dev',
  'alpine.js': 'alpinejs.dev',
  'htmx': 'htmx.org',
  'lit': 'lit.dev',
  'react': 'react.dev',
  'solidjs': 'solidjs.com',
  'vue': 'vuejs.org',
  'jquery': 'jquery.com',
  'astro': 'astro.build',
  'docusaurus': 'docusaurus.io',
  'gatsby': 'gatsbyjs.com',
  'hugo': 'gohugo.io',
  'jekyll': 'jekyllrb.com',
  'apache': 'apache.org',
  'nginx': 'nginx.org',
  'express': 'expressjs.com',
  'php': 'php.net',
  'asp.net': 'dotnet.microsoft.com',
  'google servlet engine': 'google.com',
  'gse': 'google.com',
  // WordPress plugins
  'rank math': 'rankmath.com',
  'yoast': 'yoast.com',
  'wp rocket': 'wp-rocket.me',
  'w3 total cache': 'w3-edge.com',
  'slider revolution': 'sliderrevolution.com',
  'elementor': 'elementor.com',
  'contact form 7': 'contactform7.com',
  'wpbakery': 'wpbakery.com',
  // Fonts, payments, cloud, consent
  'google fonts': 'fonts.google.com',
  'adobe fonts': 'fonts.adobe.com',
  'font awesome': 'fontawesome.com',
  'typeform': 'typeform.com',
  'ionicons': 'ionic.io',
  'boxicons': 'boxicons.com',
  'feather icons': 'feathericons.com',
  'stripe': 'stripe.com',
  'paypal': 'paypal.com',
  'klarna': 'klarna.com',
  'amazon web services': 'aws.amazon.com',
  'amazon s3': 'aws.amazon.com',
  'amazons3': 'aws.amazon.com',
  'aws': 'aws.amazon.com',
  'firebase': 'firebase.google.com',
  'azure': 'azure.microsoft.com',
  'cloudflare': 'cloudflare.com',
  'vercel': 'vercel.com',
  'netlify': 'netlify.com',
  'fastly': 'fastly.com',
  'akamai': 'akamai.com',
  'digitalocean': 'digitalocean.com',
  'heroku': 'heroku.com',
  'bunnycdn': 'bunny.net',
  'stackpath': 'stackpath.com',
  'cookiebot': 'cookiebot.com',
  'onetrust': 'onetrust.com',
  'usercentrics': 'usercentrics.com',
  'trustarc': 'trustarc.com',
  'cookieyes': 'cookieyes.com',
  'osano': 'osano.com',
  'cassie': 'cassiecloud.com',
  'complianz': 'complianz.io',
};

/// Domain whose logo represents [label] (a technology, service, tracker or
/// cookie provider name), or null when unknown.
String? logoDomainFor(String label) {
  final l = label.toLowerCase().trim();
  if (l.isEmpty) return null;
  final exact = _techDomains[l];
  if (exact != null) return exact;
  // Longest key first so "google fonts" wins over shorter keys.
  final keys = _techDomains.keys.where((k) => k.length > 3 && l.contains(k)).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (keys.isNotEmpty) return _techDomains[keys.first];
  return trackerInfoFor(label)?.iconDomain;
}
