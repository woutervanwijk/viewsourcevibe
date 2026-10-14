import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/widgets/service_logo.dart';
import 'package:view_source_vibe/widgets/evidence_view.dart';

/// Who is tracking you on this page: the tracking categories of
/// [HtmlService.detections], with logos.
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  static (IconData, Color) style(DetectionCategory c) => switch (c) {
        DetectionCategory.advertising => (Icons.ad_units_outlined, Colors.red),
        DetectionCategory.behavior => (
            Icons.videocam_outlined,
            Colors.deepOrange
          ),
        DetectionCategory.social => (Icons.share_outlined, Colors.green),
        DetectionCategory.analytics => (
            Icons.analytics_outlined,
            Colors.orange
          ),
        DetectionCategory.marketing => (Icons.campaign_outlined, Colors.blue),
        _ => (Icons.category_outlined, Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);

    if (htmlService.isLoading ||
        htmlService.isWebViewLoading ||
        htmlService.isExtractingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }

    final hits =
        htmlService.detections.where((d) => d.category.isTracking).toList();

    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Trackers Detected'),
            const SizedBox(height: 8),
            const Text('No known trackers found on this page.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final byCategory = {
      for (final c in DetectionCategory.values.where((c) => c.isTracking))
        c: hits.where((h) => h.category == c).toList(),
    }..removeWhere((_, v) => v.isEmpty);

    return Scrollbar(
      child: SingleChildScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hits.length} ${hits.length == 1 ? 'tracker follows' : 'trackers follow'} you here',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in byCategory.entries)
                  _chip(e.key.label, e.value.length, style(e.key)),
              ],
            ),
            for (final e in byCategory.entries) ...[
              const SizedBox(height: 24),
              Text(
                '${e.key.label} (${e.value.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: style(e.key).$2,
                    ),
              ),
              const SizedBox(height: 8),
              ...e.value.map((hit) => _TrackerTile(hit: hit)),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int count, (IconData, Color) style) {
    final (icon, color) = style;
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
          Text('$count $label',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TrackerTile extends StatelessWidget {
  final Detection hit;
  const _TrackerTile({required this.hit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fallbackIcon, color) = PrivacyView.style(hit.category);
    final details = [
      if (hit.requests > 0)
        '${hit.requests} request${hit.requests == 1 ? '' : 's'}',
      if (hit.inSource && hit.requests == 0) 'in page source',
      if (hit.hintOnly) 'connection hint only',
      if (hit.cookies.isNotEmpty)
        '${hit.cookies.length} cookie${hit.cookies.length == 1 ? '' : 's'}',
    ].join(' · ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: ServiceLogo(
            domain: hit.entity.logoDomain,
            label: hit.name,
            fallback: fallbackIcon,
            color: color,
            size: 36),
        title:
            Text(hit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty)
              Text(details, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(height: 4),
            EvidenceList(evidence: hit.evidence, max: 3, compact: true),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showEvidenceSheet(context, hit.name, hit.evidence,
            leading: ServiceLogo(
                domain: hit.entity.logoDomain,
                label: hit.name,
                fallback: fallbackIcon,
                color: color,
                size: 28)),
      ),
    );
  }
}
