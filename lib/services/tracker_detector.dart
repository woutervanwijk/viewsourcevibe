// Detects known trackers from the URLs a page loads and the cookies it sets.

enum TrackerCategory {
  advertising('Advertising', 5),
  behavior('Session recording', 4),
  social('Social', 3),
  analytics('Analytics', 2),
  marketing('Marketing', 1);

  final String label;
  final int weight;
  const TrackerCategory(this.label, this.weight);
}

class TrackerInfo {
  final String name;
  final TrackerCategory category;

  /// Hosts (and their subdomains) that identify this tracker.
  final List<String> domains;

  /// Lowercase cookie-provider names that map to this tracker.
  final List<String> aliases;

  /// Domain used to fetch the logo; defaults to the first of [domains].
  final String? icon;

  const TrackerInfo(this.name, this.category, this.domains,
      {this.aliases = const [], this.icon});

  String get iconDomain => icon ?? domains.first;
}

class TrackerHit {
  final String name;
  final TrackerCategory category;
  final String? iconDomain;
  final Set<String> hosts = {};
  final Set<String> cookies = {};
  int requests = 0;

  /// Found in the page source (inline snippets, pixels) rather than as a request.
  bool inSource = false;

  TrackerHit(this.name, this.category, this.iconDomain);
}

const trackerDatabase = <TrackerInfo>[
  // Advertising
  TrackerInfo(
      'Google Ads',
      TrackerCategory.advertising,
      [
        'ads.google.com',
        'doubleclick.net',
        'googleadservices.com',
        'googlesyndication.com',
        '2mdn.net',
        'adservice.google.com',
      ],
      aliases: ['google', 'google ads', 'doubleclick']),
  TrackerInfo(
      'Meta Pixel',
      TrackerCategory.advertising,
      ['facebook.com', 'connect.facebook.net', 'facebook.net'],
      aliases: ['facebook', 'meta', 'instagram']),
  TrackerInfo('Microsoft Advertising', TrackerCategory.advertising,
      ['bat.bing.com', 'ads.microsoft.com'],
      aliases: ['bing / microsoft', 'bing'], icon: 'ads.microsoft.com'),
  TrackerInfo('TikTok Pixel', TrackerCategory.advertising,
      ['analytics.tiktok.com', 'tiktok.com'],
      aliases: ['tiktok']),
  TrackerInfo('LinkedIn Insight', TrackerCategory.advertising,
      ['linkedin.com', 'snap.licdn.com', 'px.ads.linkedin.com'],
      aliases: ['linkedin']),
  TrackerInfo('Pinterest Tag', TrackerCategory.advertising,
      ['pinterest.com', 'ct.pinterest.com'],
      aliases: ['pinterest']),
  TrackerInfo('X / Twitter Ads', TrackerCategory.advertising,
      ['ads-twitter.com', 'analytics.twitter.com', 'twitter.com', 't.co'],
      aliases: ['x', 'twitter']),
  TrackerInfo('Snapchat Pixel', TrackerCategory.advertising,
      ['sc-static.net', 'snapchat.com'],
      aliases: ['snapchat', 'snap']),
  TrackerInfo('Reddit Pixel', TrackerCategory.advertising,
      ['alb.reddit.com', 'redditstatic.com'],
      aliases: ['reddit']),
  TrackerInfo('Amazon Ads', TrackerCategory.advertising,
      ['amazon-adsystem.com', 'amazon.com'],
      aliases: ['amazon']),
  TrackerInfo('Criteo', TrackerCategory.advertising, ['criteo.com', 'criteo.net']),
  TrackerInfo('Taboola', TrackerCategory.advertising, ['taboola.com']),
  TrackerInfo('Outbrain', TrackerCategory.advertising, ['outbrain.com']),
  TrackerInfo('AdRoll', TrackerCategory.advertising, ['adroll.com']),
  TrackerInfo('The Trade Desk', TrackerCategory.advertising, ['adsrvr.org'],
      icon: 'thetradedesk.com'),
  TrackerInfo('PubMatic', TrackerCategory.advertising, ['pubmatic.com']),
  TrackerInfo('Magnite (Rubicon)', TrackerCategory.advertising,
      ['rubiconproject.com', 'magnite.com'],
      aliases: ['rubicon', 'magnite']),
  TrackerInfo('OpenX', TrackerCategory.advertising, ['openx.net']),
  TrackerInfo('Xandr (AppNexus)', TrackerCategory.advertising, ['adnxs.com'],
      icon: 'xandr.com', aliases: ['appnexus', 'xandr']),
  TrackerInfo('Index Exchange', TrackerCategory.advertising,
      ['casalemedia.com', 'indexww.com'],
      icon: 'indexexchange.com'),
  TrackerInfo('Adform', TrackerCategory.advertising, ['adform.net']),
  TrackerInfo('Smart AdServer', TrackerCategory.advertising,
      ['smartadserver.com'],
      aliases: ['smartadserver']),
  TrackerInfo('Teads', TrackerCategory.advertising, ['teads.tv']),
  TrackerInfo('Yahoo Ads', TrackerCategory.advertising,
      ['ads.yahoo.com', 'analytics.yahoo.com', 'yahoo.com'],
      aliases: ['yahoo']),
  TrackerInfo('LiveRamp', TrackerCategory.advertising, ['rlcdn.com', 'liveramp.com']),
  TrackerInfo('Lotame', TrackerCategory.advertising, ['crwdcntrl.net', 'lotame.com']),
  TrackerInfo('Adobe Audience Manager', TrackerCategory.advertising,
      ['demdex.net'],
      icon: 'adobe.com', aliases: ['adobe advertising']),
  // Session recording
  TrackerInfo('Hotjar', TrackerCategory.behavior, ['hotjar.com', 'hotjar.io']),
  TrackerInfo('Microsoft Clarity', TrackerCategory.behavior, ['clarity.ms'],
      aliases: ['clarity']),
  TrackerInfo('FullStory', TrackerCategory.behavior, ['fullstory.com']),
  TrackerInfo('Mouseflow', TrackerCategory.behavior, ['mouseflow.com']),
  TrackerInfo('Crazy Egg', TrackerCategory.behavior, ['crazyegg.com']),
  TrackerInfo('Lucky Orange', TrackerCategory.behavior,
      ['luckyorange.com', 'luckyorange.net']),
  TrackerInfo('Smartlook', TrackerCategory.behavior, ['smartlook.com']),
  TrackerInfo('LogRocket', TrackerCategory.behavior,
      ['logrocket.com', 'lr-ingest.io']),
  TrackerInfo('Inspectlet', TrackerCategory.behavior, ['inspectlet.com']),
  TrackerInfo('Contentsquare', TrackerCategory.behavior,
      ['contentsquare.com', 'contentsquare.net'],
      aliases: ['contentsquare']),
  // Social
  TrackerInfo('YouTube', TrackerCategory.social, ['youtube.com', 'ytimg.com']),
  TrackerInfo('Vimeo', TrackerCategory.social, ['vimeo.com', 'vimeocdn.com']),
  TrackerInfo('AddThis', TrackerCategory.social, ['addthis.com', 'addthisedge.com']),
  TrackerInfo('ShareThis', TrackerCategory.social, ['sharethis.com']),
  TrackerInfo('Disqus', TrackerCategory.social, ['disqus.com', 'disquscdn.com']),
  TrackerInfo('Twitch', TrackerCategory.social, ['twitch.tv']),
  TrackerInfo('Instagram', TrackerCategory.social, ['instagram.com', 'cdninstagram.com']),
  TrackerInfo('Spotify', TrackerCategory.social, ['spotify.com', 'scdn.co']),
  // Analytics
  TrackerInfo('Google Analytics', TrackerCategory.analytics,
      ['analytics.google.com', 'google-analytics.com']),
  TrackerInfo('Google Tag Manager', TrackerCategory.analytics,
      ['tagmanager.google.com', 'googletagmanager.com']),
  TrackerInfo('Adobe Analytics', TrackerCategory.analytics,
      ['omtrdc.net', '2o7.net', 'adobedc.net', 'adobedtm.com'],
      icon: 'adobe.com'),
  TrackerInfo('Matomo', TrackerCategory.analytics, ['matomo.cloud', 'matomo.org'],
      aliases: ['piwik']),
  TrackerInfo('Piwik PRO', TrackerCategory.analytics, ['piwik.pro']),
  TrackerInfo('Mixpanel', TrackerCategory.analytics, ['mixpanel.com', 'mxpnl.com']),
  TrackerInfo('Segment', TrackerCategory.analytics, ['segment.com', 'segment.io']),
  TrackerInfo('Amplitude', TrackerCategory.analytics, ['amplitude.com']),
  TrackerInfo('Heap', TrackerCategory.analytics, ['heapanalytics.com', 'heap.io']),
  TrackerInfo('Plausible', TrackerCategory.analytics, ['plausible.io']),
  TrackerInfo('Fathom', TrackerCategory.analytics, ['usefathom.com']),
  TrackerInfo('Yandex Metrica', TrackerCategory.analytics,
      ['mc.yandex.ru', 'mc.yandex.com'],
      icon: 'metrica.yandex.com', aliases: ['yandex']),
  TrackerInfo('Cloudflare Analytics', TrackerCategory.analytics,
      ['cloudflareinsights.com'],
      icon: 'cloudflare.com'),
  TrackerInfo('New Relic', TrackerCategory.analytics,
      ['newrelic.com', 'nr-data.net']),
  TrackerInfo('Chartbeat', TrackerCategory.analytics,
      ['chartbeat.com', 'chartbeat.net']),
  TrackerInfo('Parse.ly', TrackerCategory.analytics, ['parsely.com']),
  TrackerInfo('Comscore', TrackerCategory.analytics,
      ['scorecardresearch.com', 'comscore.com']),
  TrackerInfo('Quantcast', TrackerCategory.analytics,
      ['quantserve.com', 'quantcount.com', 'quantcast.com']),
  TrackerInfo('Nielsen', TrackerCategory.analytics, ['imrworldwide.com'],
      icon: 'nielsen.com'),
  // Marketing
  TrackerInfo('HubSpot', TrackerCategory.marketing,
      ['hubspot.com', 'hs-analytics.net', 'hs-scripts.com', 'hs-banner.com'],
      aliases: ['hubspot']),
  TrackerInfo('Klaviyo', TrackerCategory.marketing, ['klaviyo.com']),
  TrackerInfo('Mailchimp', TrackerCategory.marketing,
      ['mailchimp.com', 'chimpstatic.com', 'list-manage.com']),
  TrackerInfo('Marketo', TrackerCategory.marketing,
      ['marketo.net', 'marketo.com', 'mktoresp.com']),
  TrackerInfo('Pardot', TrackerCategory.marketing, ['pardot.com']),
  TrackerInfo('Intercom', TrackerCategory.marketing,
      ['intercom.io', 'intercomcdn.com']),
  TrackerInfo('ActiveCampaign', TrackerCategory.marketing,
      ['activecampaign.com', 'trackcmp.net']),
  TrackerInfo('Drift', TrackerCategory.marketing, ['drift.com', 'driftt.com']),
  TrackerInfo('Zendesk', TrackerCategory.marketing,
      ['zendesk.com', 'zdassets.com']),
  TrackerInfo('Crisp', TrackerCategory.marketing, ['crisp.chat']),
  TrackerInfo('Tawk.to', TrackerCategory.marketing, ['tawk.to']),
  TrackerInfo('Salesforce', TrackerCategory.marketing,
      ['salesforce.com', 'force.com']),
];

TrackerInfo? _byHost(String host) {
  for (final t in trackerDatabase) {
    if (t.domains.any((d) => host == d || host.endsWith('.$d'))) return t;
  }
  return null;
}

TrackerInfo? _byProvider(String provider) {
  final p = provider.toLowerCase();
  List<String> names(TrackerInfo t) => [t.name.toLowerCase(), ...t.aliases];
  for (final t in trackerDatabase) {
    if (names(t).contains(p)) return t;
  }
  for (final t in trackerDatabase) {
    if (names(t).any((a) => a.length > 3 && p.contains(a))) return t;
  }
  return null;
}

String _hostOf(String url) {
  if (url.startsWith('data:')) return '';
  return Uri.tryParse(url)?.host.toLowerCase() ?? '';
}

/// Every URL a page references: metadata links plus the browser's resource
/// timeline entries (maps with a `name`).
List<String> collectResourceUrls(
    Map<String, dynamic>? metadata, Iterable<Map<String, dynamic>> timeline) {
  final urls = <String>[];

  void add(dynamic value) {
    final raw = value is Map ? value['src'] ?? value['href'] ?? value['name'] : value;
    if (raw is String && raw.isNotEmpty) urls.add(raw);
  }

  if (metadata != null) {
    for (final key in [
      'jsLinks',
      'externalJsLinks',
      'cssLinks',
      'externalCssLinks',
      'iframeLinks',
      'externalIframeLinks',
    ]) {
      final list = metadata[key];
      if (list is List) list.forEach(add);
    }
    final media = metadata['media'];
    if (media is Map) {
      for (final key in ['images', 'videos']) {
        final list = media[key];
        if (list is List) list.forEach(add);
      }
    }
  }
  timeline.forEach(add);
  return urls;
}

/// Groups trackers by name, combining request hosts and cookies.
/// Requests to the page's own host are ignored.
List<TrackerHit> detectTrackers({
  required String pageUrl,
  required Iterable<String> resourceUrls,
  required Iterable<Map> cookies,
  Map<String, List<String>> services = const {},
}) {
  final pageHost = _hostOf(pageUrl);
  final hits = <String, TrackerHit>{};

  TrackerHit hitFor(TrackerInfo t) =>
      hits.putIfAbsent(t.name, () => TrackerHit(t.name, t.category, t.iconDomain));

  for (final url in resourceUrls.toSet()) {
    final host = _hostOf(url);
    if (host.isEmpty) continue;
    if (pageHost.isNotEmpty &&
        (host == pageHost ||
            host.endsWith('.$pageHost') ||
            pageHost.endsWith('.$host'))) {
      continue;
    }
    final info = _byHost(host);
    if (info == null) continue;
    hitFor(info)
      ..requests += 1
      ..hosts.add(host);
  }

  for (final cookie in cookies) {
    final category = cookie['category']?.toString();
    final provider = cookie['provider']?.toString() ?? '';
    final name = cookie['name']?.toString() ?? '';
    final domain = (cookie['domain']?.toString() ?? '').replaceFirst(RegExp(r'^\.'), '');
    if (provider.isEmpty ||
        (category != 'analytics' &&
            category != 'advertising' &&
            category != 'social')) {
      continue;
    }
    final info = _byHost(domain.toLowerCase()) ?? _byProvider(provider);
    final hit = info != null
        ? hitFor(info)
        : hits.putIfAbsent(
            provider,
            () => TrackerHit(
                provider,
                TrackerCategory.values.firstWhere((c) => c.name == category),
                null));
    hit.cookies.add(name);
  }

  // Services found by pattern in the page source (inline snippets etc.).
  const serviceCategories = {
    'Analytics & Trackers': TrackerCategory.analytics,
    'Advertising': TrackerCategory.advertising,
    'Marketing & CRM': TrackerCategory.marketing,
    'Social & Widgets': TrackerCategory.social,
  };
  services.forEach((group, names) {
    final category = serviceCategories[group];
    if (category == null) return;
    for (final name in names) {
      final info = _byProvider(name);
      // Unknown social widgets (share links etc.) are not trackers.
      if (info == null && category == TrackerCategory.social) continue;
      (info != null
              ? hitFor(info)
              : hits.putIfAbsent(name, () => TrackerHit(name, category, null)))
          .inSource = true;
    }
  });

  return hits.values.toList()
    ..sort((a, b) {
      final byCategory = b.category.weight.compareTo(a.category.weight);
      return byCategory != 0
          ? byCategory
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}
