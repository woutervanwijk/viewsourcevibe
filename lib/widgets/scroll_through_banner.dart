import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// Shown above the browser view when the page was scrolled through
/// automatically once, so the movement is not mistaken for user input.
/// Dismissing hides it until the next page load.
class ScrollThroughBanner extends StatelessWidget {
  const ScrollThroughBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final show = context.select<HtmlService, bool>(
      (s) => s.showScrollThroughBanner,
    );
    if (!show) return const SizedBox.shrink();
    return Container(
      color: Colors.red,
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.unfold_more, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              HtmlService.scrollThroughBannerText,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.white),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                context.read<HtmlService>().dismissScrollThroughBanner(),
          ),
        ],
      ),
    );
  }
}
