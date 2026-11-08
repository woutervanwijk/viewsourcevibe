import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/derive/divergences.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// "curl ≠ browser": shown above the tabs when the app's own request and the
/// browser disagree (bot block, other final URL, other content type), so no
/// tab silently mixes the two. Low-severity notes (www <-> non-www) are
/// collapsed. Dismissing hides a message until the page reports a different
/// one.
class DivergenceBanner extends StatefulWidget {
  const DivergenceBanner({super.key});

  @override
  State<DivergenceBanner> createState() => _DivergenceBannerState();
}

class _DivergenceBannerState extends State<DivergenceBanner> {
  final Set<String> _dismissed = {};
  bool _showMinor = false;

  @override
  Widget build(BuildContext context) {
    return Selector<HtmlService, List<Divergence>>(
      selector: (_, service) => service.divergences,
      shouldRebuild: (a, b) => !listEquals(
          a.map((d) => d.message).toList(), b.map((d) => d.message).toList()),
      builder: (context, all, _) {
        final visible =
            all.where((d) => !_dismissed.contains(d.message)).toList();
        final major = visible.where((d) => !d.lowSeverity).toList();
        final minor = visible.where((d) => d.lowSeverity).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (major.isNotEmpty) _major(context, major),
            if (minor.isNotEmpty) _minor(context, minor, theme),
          ],
        );
      },
    );
  }

  void _dismiss(List<Divergence> ds) =>
      setState(() => _dismissed.addAll(ds.map((d) => d.message)));

  Widget _major(BuildContext context, List<Divergence> ds) {
    return Container(
      color: Colors.orange.withValues(alpha: 0.14),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.compare_arrows, color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('curl ≠ browser',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                for (final d in ds)
                  Text(d.message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: () => _dismiss(ds),
          ),
        ],
      ),
    );
  }

  Widget _minor(BuildContext context, List<Divergence> ds, ThemeData theme) {
    final muted =
        TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);
    final n = ds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showMinor = !_showMinor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_showMinor ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                    '$n minor difference${n == 1 ? '' : 's'} between curl and browser',
                    style: muted),
              ],
            ),
          ),
          if (_showMinor)
            for (final d in ds) Text(d.message, style: muted),
        ],
      ),
    );
  }
}
