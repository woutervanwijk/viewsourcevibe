import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/file_viewer.dart';
import 'package:view_source_vibe/widgets/toolbar.dart';
import 'package:view_source_vibe/widgets/url_input.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.asset(
                      'assets/icon.webp',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Text(
                    'View\nSource\nVibe',
                    style: TextStyle(fontSize: 10, height: 1),
                  ),
                ],
              ),
            ),
          ),
          actions: const [
            Toolbar(),
          ],
          centerTitle: false,
        ),
        body: Column(
          children: [
            const UrlInput(),
            // The Toolbar with Navigation Tabs
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  _buildTab(Icons.code, 'Editor'),
                  _buildTab(Icons.info_outline, 'Metadata'),
                  _buildTab(Icons.network_check, 'Probe'),
                  _buildTab(Icons.list_alt, 'Headers'),
                  _buildTab(Icons.security, 'Security'),
                  _buildTab(Icons.cookie_outlined, 'Cookies'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<HtmlService>(
                builder: (context, htmlService, child) {
                  if (htmlService.currentFile == null) {
                    return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            'No file loaded\n\nEnter an url to view the source\nOr share a file or url to this app\nOr tap the folder icon to open a local file',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(153),
                            ),
                          ),
                        ));
                  }

                  final currentFile = htmlService.currentFile;

                  return TabBarView(
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe to prevent conflict with editor
                    children: [
                      // 1. Editor
                      currentFile != null
                          ? FileViewer(
                              file: currentFile,
                              scrollController: _scrollController,
                            )
                          : const Center(child: Text('No File')),

                      // 2. Metadata
                      const MetadataView(),

                      // 3. Probe: General
                      const ProbeGeneralView(),

                      // 4. Probe: Headers
                      const ProbeHeadersView(),

                      // 5. Probe: Security
                      const ProbeSecurityView(),

                      // 6. Probe: Cookies
                      const ProbeCookiesView(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        // No FAB anymore as Metadata is a tab
      ),
    );
  }

  Widget _buildTab(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
