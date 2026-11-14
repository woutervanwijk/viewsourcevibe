import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/safe_network_svg.dart';
import 'package:view_source_vibe/widgets/service_logo.dart';

/// File-type filter tabs: resource type (null = all) and label, matching
/// the breakdown rows.
const _typeFilters = <(String?, String)>[
  (null, 'All'),
  ('script', 'External JS'),
  ('style', 'CSS Files'),
  ('image', 'Images/Media'),
  ('document', 'HTML/Content'),
  ('other', 'Misc. Resources'),
];

/// Page size/weight: totals, a per-type breakdown and every loaded
/// file/asset sorted by size. Everything comes from the store's browser
/// resources ([HtmlService.pageSize]); a size that was not reported is shown
/// as unknown, never as 0.
class PageSizeView extends StatefulWidget {
  const PageSizeView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  State<PageSizeView> createState() => _PageSizeViewState();
}

class _PageSizeViewState extends State<PageSizeView>
    with SingleTickerProviderStateMixin {
  late final TabController _filterController =
      TabController(length: _typeFilters.length, vsync: this)
        ..addListener(() => setState(() {}));

  /// Show the fresh load's files (when there is one) or this load's.
  bool _showFresh = true;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Widget _message(
      BuildContext context, IconData icon, String title, String text,
      {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(title),
            const SizedBox(height: 8),
            Text(text,
                style: TextStyle(color: error ? scheme.error : Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PageSizeView.builds++;
    final state =
        context.select<HtmlService, Observed<PageSizeModel>>((s) => s.pageSize);
    final isFile = context
        .select<HtmlService, bool>((s) => s.store.current.target is FileTarget);

    switch (state) {
      case Pending<PageSizeModel>():
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Waiting for the browser…',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      case Failed<PageSizeModel>(:final error):
        return _message(context, Icons.error_outline,
            'Page size could not be measured', error,
            error: true);
      case Unavailable<PageSizeModel>(:final reason, :final detail):
        return _message(
            context,
            Icons.scale_outlined,
            'Page size not available',
            isFile
                ? 'Page size is measured by the browser and is not available for local files.'
                : 'Page size is measured by the browser. ${unavailableMessage(reason, detail)}.');
      case Present<PageSizeModel>(value: final model):
        return _buildModel(context, model);
    }
  }

  Widget _buildModel(BuildContext context, PageSizeModel model) {
    final htmlService = context.read<HtmlService>();
    final isFile = context
        .select<HtmlService, bool>((s) => s.store.current.target is FileTarget);
    final loadLazy =
        context.select<AppSettings, bool>((s) => s.scrollToLoadLazy);
    final fresh = model.fresh;
    // The fresh load's files once there is one, unless the user picked this
    // load.
    final active =
        _showFresh && fresh is Present<PageSizeModel> ? fresh.value : model;
    final resources = active.rows;
    final totalSize = model.knownRowTotal;
    final filterType = _typeFilters[_filterController.index].$1;
    final shown = filterType == null
        ? resources
        : resources.where((r) => r.type == filterType).toList();

    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          _buildTotalsCard(context, model, active),
          if (!isFile && !loadLazy) ...[
            const SizedBox(height: 12),
            _lazyContentNote(context),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle(
              context, 'Loaded Files & Assets (${resources.length})'),
          if (resources.isNotEmpty) ...[
            _buildFilterTabs(context, resources),
            const SizedBox(height: 12),
          ],
          if (shown.isEmpty)
            Text(
              resources.isEmpty
                  ? 'The browser reported no individual resources.'
                  : 'No files of this type.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            _outlinedCard(
              context,
              Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildResourceRow(
                        context, htmlService, shown[i], totalSize),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, List<PageSizeRow> resources) {
    return TabBar(
      controller: _filterController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerHeight: 0,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      tabs: [
        for (final (type, label) in _typeFilters)
          Tab(
            height: 36,
            text:
                '$label (${type == null ? resources.length : resources.where((r) => r.type == type).length})',
          ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _outlinedCard(BuildContext context, Widget child) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  /// Shown while "Load lazy content" is off: the page was never scrolled,
  /// so lazy resources were not fetched and the totals can be too low.
  Widget _lazyContentNote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _outlinedCard(
      context,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.vertical_align_bottom, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sizes may be underestimated: lazy content (loading="lazy" '
                'images, IntersectionObserver embeds) is only fetched when '
                'scrolled into view, and this page was not scrolled. Turn on '
                'Settings → Behavior → "Load lazy content" to scroll each '
                'page once after it loads, so those resources load and are '
                'measured for real.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text, {bool italic = true}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text(
          '${text[0].toUpperCase()}${text.substring(1)}',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );

  /// One total line: label, then the size or what stands in for it.
  Widget _totalLine(BuildContext context, String label, Widget value,
      {bool selected = false, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        ),
      ),
    );
  }

  /// A small phone-shaped screenshot of a load; tap to see it larger.
  Widget _thumbnail(
      BuildContext context, String label, Observed<Uint8List> shot) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = shot is Present<Uint8List> ? shot.value : null;
    return Tooltip(
      message: bytes == null ? '$label: no screenshot' : label,
      child: InkWell(
        onTap: bytes == null
            ? null
            : () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(label),
                        ),
                        Flexible(child: Image.memory(bytes)),
                      ],
                    ),
                  ),
                ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
                color: scheme.surfaceContainerHighest,
              ),
              child: bytes == null
                  ? Icon(Icons.image_not_supported_outlined,
                      size: 18, color: scheme.onSurfaceVariant)
                  : Image.memory(bytes,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _sizeText(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
        textAlign: TextAlign.end,
      );

  Widget _freshValue(BuildContext context, Observed<PageSizeModel> fresh) {
    final service = context.read<HtmlService>();
    final small = TextStyle(
        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return switch (fresh) {
      Present<PageSizeModel>(value: final f) => _sizeText(formatDownloadSize(
              f.weight.transfer,
              prefix: f.weight.transferPrefix) ??
          'size unknown'),
      Pending<PageSizeModel>() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('measuring… (up to 45 s)', style: small),
          ],
        ),
      Unavailable<PageSizeModel>(
        reason: UnavailableReason.unsupportedPlatform
      ) =>
        Text('not available on this platform', style: small),
      Failed<PageSizeModel>(:final error) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(error,
                  style: small.copyWith(
                      color: Theme.of(context).colorScheme.error),
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton(
                onPressed: service.measureFreshLoad,
                child: const Text('Retry')),
          ],
        ),
      Unavailable<PageSizeModel>() => FilledButton.tonal(
          onPressed: service.measureFreshLoad,
          child: const Text('Measure'),
        ),
    };
  }

  Widget _buildTotalsCard(
      BuildContext context, PageSizeModel model, PageSizeModel active) {
    final weight = active.weight;
    final fresh = model.fresh;
    final hasFresh = fresh is Present<PageSizeModel>;
    final live = formatDownloadSize(model.weight.transfer,
            prefix: model.weight.transferPrefix) ??
        'size unknown';
    final note = active.missingNote;

    return _outlinedCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _totalLine(
            context,
            'This load',
            _sizeText(model.stillCollecting ? '$live …' : live),
            selected: identical(active, model),
            onTap: hasFresh ? () => setState(() => _showFresh = false) : null,
          ),
          _totalLine(
            context,
            'Fresh load',
            _freshValue(context, fresh),
            selected: !identical(active, model),
            onTap: hasFresh ? () => setState(() => _showFresh = true) : null,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _note(
                        context,
                        'This load: what your browser fetched now (cache and '
                        'ads vary${model.stillCollecting ? '; still collecting' : ''}). '
                        'Fresh load: empty cache, phone screen, waits until '
                        'the network is quiet. Both are '
                        'download sizes.',
                        italic: false),
                    if (model.lighthouseNote != null)
                      _note(context, '${model.lighthouseNote!}.',
                          italic: false),
                    if (model.differenceNote != null)
                      _note(context, '${model.differenceNote!}.',
                          italic: false),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _thumbnail(context, 'This load', model.liveScreenshot),
                    if (fresh is! Unavailable<PageSizeModel>) ...[
                      const SizedBox(width: 8),
                      _thumbnail(context, 'Fresh load', model.freshScreenshot),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasFresh)
            _note(
                context,
                'Files below: ${identical(active, model) ? 'this load' : 'fresh load'}. '
                'Tap a total to switch.'),
          if (note != null)
            _note(context, '$note. The total is a lower bound.'),
          if (active.cacheNote != null) _note(context, '${active.cacheNote!}.'),
          if (active.estimateNote != null)
            _note(context, '${active.estimateNote!}.'),
          if (active.declaredNote != null)
            _note(
              context,
              '${active.declaredNote!}.',
            ),
          if (weight.documentSource != null)
            _note(context,
                'The page document is counted from the server response.',
                italic: false),
          const Divider(height: 1),
          for (final (key, label) in const [
            ('scripts', 'External JS'),
            ('css', 'CSS Files'),
            ('images', 'Images/Media'),
            ('html', 'HTML/Content'),
            ('other', 'Misc. Resources'),
            ('thirdPartyFrames', 'Third-party iframes (ads, embeds)'),
          ])
            _buildBreakdownRow(
                context, label, weight.breakdown[key], weight.transfer),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label,
      WeightBucket? bucket, int? totalTransfer) {
    if (bucket == null || bucket.count == 0) {
      return const SizedBox.shrink();
    }
    final text =
        formatDownloadSize(bucket.transfer, prefix: bucket.transferPrefix) ??
            'size unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$label (${bucket.count})',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _shareBar(context, bucket.transfer, totalTransfer),
        ],
      ),
    );
  }

  Widget _buildResourceRow(BuildContext context, HtmlService htmlService,
      PageSizeRow resource, int totalSize) {
    final scheme = Theme.of(context).colorScheme;
    final size = resource.size;
    final share = size != null && totalSize > 0 ? size / totalSize : null;
    final services = resource.services.take(2).toList();
    final host = Uri.tryParse(resource.url)?.host ?? '';
    final subtitle = [
      if (resource.thirdPartyFrame) 'third-party iframe',
      if (host.isNotEmpty) host,
      ...services.map((e) => e.name),
    ].join(' · ');

    return Material(
      color: resource.isPage
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: resource.url.startsWith('http')
            ? () => htmlService.loadFromUrl(resource.url,
                switchToTab: HtmlService.viewerTab)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_iconFor(resource.type),
                    size: 18,
                    color: resource.isPage ? scheme.primary : scheme.secondary),
              ),
              const SizedBox(width: 8),
              if (resource.type == 'image' && !resource.isAudioVideo) ...[
                _buildThumbnail(context, resource.url),
                const SizedBox(width: 8),
              ],
              for (final service in services) ...[
                Tooltip(
                  message: service.name,
                  child: ServiceLogo(
                    domain: service.logoDomain,
                    label: service.name,
                    fallback: Icons.extension_outlined,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (services.isNotEmpty) const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: resource.url,
                      child: Text(
                        resource.isPage
                            ? 'This page HTML (${_pageName(resource.url)})'
                            : _fileName(resource.url),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: resource.isPage
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: resource.isPage ? scheme.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    _shareBar(context, size, totalSize),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      resource.sizeLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Courier',
                          fontStyle: size == null
                              ? FontStyle.italic
                              : FontStyle.normal),
                    ),
                    if (share != null)
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Last path segment, or the host for root URLs.
  static String _fileName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    // pathSegments are already percent-decoded; decoding again throws on a
    // stray '%' or non-ASCII (same fix as ResourceSize.fileName on main).
    if (segments.isNotEmpty) return segments.last;
    return uri.host.isNotEmpty ? uri.host : url;
  }

  /// File name of the page document, `index` for root URLs.
  static String _pageName(String url) {
    final hasPath =
        Uri.tryParse(url)?.pathSegments.any((s) => s.isNotEmpty) ?? false;
    return hasPath ? _fileName(url) : 'index';
  }

  Widget _buildThumbnail(BuildContext context, String url) {
    const size = 28.0;
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.broken_image_outlined,
        size: 16, color: scheme.outlineVariant);
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: path.endsWith('.svg')
            ? SafeNetworkSvg(
                url: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => fallback,
                errorWidget: fallback,
              )
            : Image.network(url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 64,
                errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }

  /// Share of [total]; an unknown value gets an empty bar, not a measured one.
  Widget _shareBar(BuildContext context, int? value, int? total) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value != null && total != null && total > 0
            ? (value / total).clamp(0.0, 1.0)
            : 0,
        minHeight: 4,
        backgroundColor: scheme.surfaceContainerHighest,
        color: scheme.primary,
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'script' => Icons.javascript,
        'style' => Icons.style_outlined,
        'image' => Icons.image_outlined,
        'document' => Icons.description_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
}
