import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/derive/block_page.dart';
import '../services/html_service.dart';

/// Banner above the tabs that analyse the page content, shown when the
/// browser got an error, block or challenge page instead of the site.
class BlockPageBanner extends StatelessWidget {
  const BlockPageBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final block = context.select<HtmlService, BlockPage?>((s) => s.blockPage);
    if (block == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('block-page-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The browser got ${block.aLabel}, not the site. '
              'What this tab shows describes that page.',
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
