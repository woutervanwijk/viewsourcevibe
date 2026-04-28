import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import '../utils/format_utils.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final metadata = htmlService.pageMetadata;
    final services =
        metadata?['detectedServices'] as Map<String, List<String>>?;
    final trackerFindings = _trackerFindings(metadata, htmlService);

    // Show loading indicator only if we're still loading or extracting metadata
    if (htmlService.isLoading ||
        htmlService.isWebViewLoading ||
        htmlService.isExtractingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show message if no services detected or metadata is not available
    if ((metadata == null || services == null || services.isEmpty) &&
        trackerFindings.isEmpty) {
      // For XML files, we should never show progress - they don't have services
      if (htmlService.isXml) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers_clear_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 16),
              const Text('No Services Detected'),
              const SizedBox(height: 8),
              const Text('Services are not available for XML content.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Services Detected'),
            const SizedBox(height: 8),
            const Text('No common third-party services found on this page.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Sort the detected services by category name
    final sortedEntries = (services?.entries.toList() ?? [])
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Scrollbar(
        child: SingleChildScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            _buildSectionTitle(context, 'Tracker Radar'),
            _buildTrackerRadar(context, trackerFindings),
            const SizedBox(height: 24),
            if (sortedEntries.isNotEmpty) ...[
              _buildSectionTitle(context, 'Detected Services'),
              const Text(
                'Common third-party services, trackers, and infrastructure used by this page.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ...sortedEntries.map((entry) {
                return _buildServiceCategory(context, entry.key, entry.value);
              }),
            ],
            if (metadata?['analyzedCookies'] != null &&
                (metadata?['analyzedCookies'] as List).isNotEmpty)
              ..._buildCookieSection(
                  context, metadata?['analyzedCookies'] as List),
            if (metadata != null) ...[
              const Divider(height: 48),
              _buildSectionTitle(context, 'External Resources'),
              const Text(
                'JavaScript and CSS files loaded by this page.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildResourceSection(
                  context,
                  'Scripts (JS)',
                  [
                    ...(metadata['jsLinks'] ?? []),
                    ...(metadata['externalJsLinks'] ?? [])
                  ],
                  Icons.javascript),
              const SizedBox(height: 16),
              _buildResourceSection(
                  context,
                  'Stylesheets (CSS)',
                  [
                    ...(metadata['cssLinks'] ?? []),
                    ...(metadata['externalCssLinks'] ?? [])
                  ],
                  Icons.css),
              const SizedBox(height: 16),
              _buildResourceSection(
                  context,
                  'Iframes (HTML)',
                  [
                    ...(metadata['iframeLinks'] ?? []),
                    ...(metadata['externalIframeLinks'] ?? [])
                  ],
                  Icons.web_asset),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    ));
  }

  Widget _buildTrackerRadar(
      BuildContext context, List<_TrackerFinding> findings) {
    final high =
        findings.where((item) => item.risk == _TrackerRisk.high).length;
    final medium =
        findings.where((item) => item.risk == _TrackerRisk.medium).length;
    final low = findings.where((item) => item.risk == _TrackerRisk.low).length;
    final hosts = findings.map((item) => item.host).toSet().length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRadarChip(context, Icons.radar, '${findings.length} hits',
                    Theme.of(context).colorScheme.primary),
                _buildRadarChip(
                    context, Icons.public, '$hosts hosts', Colors.blue),
                if (high > 0)
                  _buildRadarChip(
                      context, Icons.warning_amber, '$high high', Colors.red),
                if (medium > 0)
                  _buildRadarChip(context, Icons.analytics_outlined,
                      '$medium medium', Colors.orange),
                if (low > 0)
                  _buildRadarChip(
                      context, Icons.info_outline, '$low low', Colors.grey),
              ],
            ),
            const SizedBox(height: 14),
            if (findings.isEmpty)
              Text(
                'No obvious tracker patterns found.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.62),
                ),
              )
            else
              ...findings.take(12).map((finding) {
                final color = finding.risk.color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(finding.icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    finding.provider,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  finding.risk.label,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              finding.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              finding.reason,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.62),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (findings.length > 12)
              Text(
                '+${findings.length - 12} more tracker-like resources',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceSection(
      BuildContext context, String title, List<dynamic>? links, IconData icon) {
    if (links == null || links.isEmpty) return const SizedBox.shrink();

    final sortedLinks = List<dynamic>.from(links);
    sortedLinks.sort((a, b) {
      final sizeA = a is Map ? (a['size']?['decoded'] as num? ?? 0) : 0;
      final sizeB = b is Map ? (b['size']?['decoded'] as num? ?? 0) : 0;

      if (sizeB != sizeA) {
        return sizeB.compareTo(sizeA);
      }

      final urlA = (a is Map ? (a['src'] ?? a['href'] ?? '') : a.toString())
          .toLowerCase();
      final urlB = (b is Map ? (b['src'] ?? b['href'] ?? '') : b.toString())
          .toLowerCase();
      return urlA.compareTo(urlB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sortedLinks.length.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...sortedLinks.map((link) {
          final String url = link is Map
              ? (link['src'] ?? link['href'] ?? '')
              : link.toString();
          final Map<String, dynamic>? size = link is Map ? link['size'] : null;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 4),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                url,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: size != null && (size['decoded'] as int? ?? 0) > 0
                  ? Text(
                      FormatUtils.formatBytesWithTransfer(size),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              dense: true,
              onTap: () {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.loadFromUrl(url,
                    switchToTab: htmlService.sourceTabIndex);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildServiceCategory(
      BuildContext context, String category, List<String> items) {
    IconData icon;
    Color color;

    switch (category) {
      case 'Analytics & Trackers':
        icon = Icons.analytics_outlined;
        color = Colors.orange;
        break;
      case 'Fonts & Icons':
        icon = Icons.font_download_outlined;
        color = Colors.blue;
        break;
      case 'Advertising':
        icon = Icons.ad_units_outlined;
        color = Colors.red;
        break;
      case 'Cloud & Infrastructure':
        icon = Icons.cloud_outlined;
        color = Colors.purple;
        break;
      case 'Social & Widgets':
        icon = Icons.share_outlined;
        color = Colors.green;
        break;
      case 'Uncategorized':
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
      default:
        icon = Icons.category_outlined;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  items.length.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (() {
              final sortedItems = List<String>.from(items)
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              return sortedItems.map((item) {
                return Chip(
                  label: Text(item),
                  backgroundColor: color.withValues(alpha: 0.05),
                  side: BorderSide(color: color.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  labelStyle: const TextStyle(fontSize: 13),
                );
              });
            }())
                .toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCookieSection(
      BuildContext context, List<dynamic> cookies) {
    // Group providers by display category
    final Map<String, Set<String>> grouped = {};

    for (var c in cookies) {
      if (c is! Map) continue;

      final String? provider = c['provider'];
      final String category = c['category'] ?? 'unknown';

      // If provider is missing, group under Uncategorized
      if (provider == null || provider.isEmpty) {
        grouped
            .putIfAbsent('Uncategorized', () => {})
            .add(c['name'] ?? 'Unknown Cookie');
        continue;
      }

      String displayCat = 'Cloud & Infrastructure';
      switch (category) {
        case 'analytics':
          displayCat = 'Analytics & Trackers';
          break;
        case 'advertising':
          displayCat = 'Advertising';
          break;
        case 'social':
          displayCat = 'Social & Widgets';
          break;
        case 'functional':
        case 'essential':
          displayCat = 'Cloud & Infrastructure';
          break;
      }

      grouped.putIfAbsent(displayCat, () => {}).add(provider);
    }

    if (grouped.isEmpty) return [];

    return [
      const Divider(height: 48),
      _buildSectionTitle(context, 'Detected from Cookies'),
      const Text(
        'Technologies identified by analyzing the cookies set by this page.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
      const SizedBox(height: 24),
      ...(() {
        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return sortedKeys.map((key) {
          final items = grouped[key]!.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          return _buildServiceCategory(context, key, items);
        });
      }()),
    ];
  }

  List<_TrackerFinding> _trackerFindings(
      Map<String, dynamic>? metadata, HtmlService htmlService) {
    final findings = <_TrackerFinding>[];
    final seen = <String>{};

    void addFinding(String url, String provider, _TrackerRisk risk,
        IconData icon, String reason) {
      final host = _hostFrom(url);
      if (host.isEmpty) return;
      final key = '$provider|$host|$reason';
      if (!seen.add(key)) return;
      findings.add(_TrackerFinding(
        provider: provider,
        host: host,
        risk: risk,
        icon: icon,
        reason: reason,
      ));
    }

    for (final url in _allResourceUrls(metadata, htmlService)) {
      final match = _matchTrackerUrl(url);
      if (match != null) {
        addFinding(url, match.provider, match.risk, match.icon, match.reason);
      }
    }

    final cookies = htmlService.probeResult?['analyzedCookies'] as List?;
    if (cookies != null) {
      for (final cookie in cookies) {
        if (cookie is! Map) continue;
        final category = cookie['category']?.toString() ?? 'unknown';
        if (category != 'analytics' &&
            category != 'advertising' &&
            category != 'social') {
          continue;
        }
        final provider = cookie['provider']?.toString();
        if (provider == null || provider.isEmpty) continue;
        final domain = cookie['domain']?.toString();
        final name = cookie['name']?.toString() ?? 'cookie';
        addFinding(
          domain == null || domain.isEmpty ? provider : 'https://$domain',
          provider,
          category == 'advertising' ? _TrackerRisk.high : _TrackerRisk.medium,
          category == 'social' ? Icons.share_outlined : Icons.cookie_outlined,
          'Cookie: $name',
        );
      }
    }

    findings.sort((a, b) {
      final riskCompare = b.risk.weight.compareTo(a.risk.weight);
      if (riskCompare != 0) return riskCompare;
      return a.provider.toLowerCase().compareTo(b.provider.toLowerCase());
    });
    return findings;
  }

  List<String> _allResourceUrls(
      Map<String, dynamic>? metadata, HtmlService htmlService) {
    final urls = <String>[];

    void add(dynamic value) {
      if (value is String && value.isNotEmpty) urls.add(value);
      if (value is Map) {
        final raw = value['src'] ?? value['href'] ?? value['name'];
        if (raw is String && raw.isNotEmpty) urls.add(raw);
      }
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
        if (list is List) {
          for (final item in list) {
            add(item);
          }
        }
      }

      final media = metadata['media'];
      if (media is Map) {
        for (final key in ['images', 'videos']) {
          final list = media[key];
          if (list is List) {
            for (final item in list) {
              add(item);
            }
          }
        }
      }
    }

    for (final resource in htmlService.resourceTimelineData) {
      add(resource);
    }

    return urls;
  }

  _TrackerMatch? _matchTrackerUrl(String url) {
    final lower = url.toLowerCase();
    const rules = [
      _TrackerRule(
          'Google Analytics',
          [
            'google-analytics.com',
            '/gtag/js',
            'googletagmanager.com/gtm.js',
            'googletagmanager.com/gtag/js'
          ],
          _TrackerRisk.medium,
          Icons.analytics_outlined,
          'Analytics script'),
      _TrackerRule(
          'Google Ads / DoubleClick',
          ['doubleclick.net', 'googleadservices.com', 'googlesyndication.com'],
          _TrackerRisk.high,
          Icons.ad_units_outlined,
          'Advertising network'),
      _TrackerRule(
          'Meta Pixel',
          ['connect.facebook.net', 'facebook.com/tr', 'fbcdn.net'],
          _TrackerRisk.high,
          Icons.radar,
          'Social advertising pixel'),
      _TrackerRule(
          'Microsoft Clarity',
          ['clarity.ms', 'claritybt.freshmarketer.com'],
          _TrackerRisk.medium,
          Icons.remove_red_eye_outlined,
          'Session analytics'),
      _TrackerRule('Microsoft Ads', ['bat.bing.com', 'bing.com/action'],
          _TrackerRisk.high, Icons.ad_units_outlined, 'Advertising pixel'),
      _TrackerRule('Hotjar', ['hotjar.com', 'hotjar.io'], _TrackerRisk.medium,
          Icons.local_fire_department_outlined, 'Behavior analytics'),
      _TrackerRule('TikTok Pixel', ['analytics.tiktok.com'], _TrackerRisk.high,
          Icons.radar, 'Advertising pixel'),
      _TrackerRule(
          'LinkedIn Insight',
          ['snap.licdn.com', 'px.ads.linkedin.com'],
          _TrackerRisk.high,
          Icons.business_center_outlined,
          'B2B ad pixel'),
      _TrackerRule('Pinterest Tag', ['ct.pinterest.com', 's.pinimg.com'],
          _TrackerRisk.high, Icons.push_pin_outlined, 'Advertising pixel'),
      _TrackerRule('Matomo', ['matomo.php', 'piwik.php', 'matomo.js'],
          _TrackerRisk.medium, Icons.analytics_outlined, 'Analytics endpoint'),
      _TrackerRule('Segment', ['cdn.segment.com', 'api.segment.io'],
          _TrackerRisk.medium, Icons.hub_outlined, 'Event router'),
      _TrackerRule('Amplitude', ['amplitude.com', 'amplitude.com/libs'],
          _TrackerRisk.medium, Icons.query_stats, 'Product analytics'),
    ];

    for (final rule in rules) {
      if (rule.patterns.any(lower.contains)) {
        return _TrackerMatch(
          rule.provider,
          rule.risk,
          rule.icon,
          rule.reason,
        );
      }
    }
    return null;
  }

  String _hostFrom(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return url.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
  }
}

enum _TrackerRisk {
  low('low', 1, Colors.grey),
  medium('medium', 2, Colors.orange),
  high('high', 3, Colors.red);

  final String label;
  final int weight;
  final Color color;

  const _TrackerRisk(this.label, this.weight, this.color);
}

class _TrackerFinding {
  final String provider;
  final String host;
  final _TrackerRisk risk;
  final IconData icon;
  final String reason;

  const _TrackerFinding({
    required this.provider,
    required this.host,
    required this.risk,
    required this.icon,
    required this.reason,
  });
}

class _TrackerRule {
  final String provider;
  final List<String> patterns;
  final _TrackerRisk risk;
  final IconData icon;
  final String reason;

  const _TrackerRule(
      this.provider, this.patterns, this.risk, this.icon, this.reason);
}

class _TrackerMatch {
  final String provider;
  final _TrackerRisk risk;
  final IconData icon;
  final String reason;

  const _TrackerMatch(this.provider, this.risk, this.icon, this.reason);
}
