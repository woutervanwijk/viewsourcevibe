import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/widgets/file_viewer.dart';
import 'package:view_source_vibe/widgets/toolbar.dart';
import 'package:view_source_vibe/widgets/url_input.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';
import 'package:view_source_vibe/widgets/services_view.dart';
import 'package:view_source_vibe/widgets/media_view.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';
import 'package:view_source_vibe/widgets/keep_alive_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  bool _lastIsHtmlOrXml = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Use addPostFrameCallback to initialize correct length after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      _updateTabs(htmlService.isHtmlOrXml, force: true);
    });
  }

  void _handleTabSelection() {
    setState(() {
      // Rebuild to update FAB visibility based on _tabController.index
    });
  }

  void _updateTabs(bool isHtmlOrXml, {bool force = false}) {
    if (isHtmlOrXml == _lastIsHtmlOrXml && !force) return;

    final oldIndex = _tabController.index;
    final oldLength = _tabController.length;
    final newLength = isHtmlOrXml ? 8 : 5;

    if (oldLength != newLength || force) {
      _tabController.removeListener(_handleTabSelection);
      // We don't dispose here if called during build to avoid issues
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, newLength - 1),
      );
      _tabController.addListener(_handleTabSelection);
      _lastIsHtmlOrXml = isHtmlOrXml;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _getTabs(bool isHtmlOrXml) {
    return [
      _buildTab(Icons.code, 'Editor'),
      if (isHtmlOrXml) _buildTab(Icons.info_outline, 'Metadata'),
      if (isHtmlOrXml) _buildTab(Icons.layers_outlined, 'Services'),
      if (isHtmlOrXml) _buildTab(Icons.perm_media_outlined, 'Media'),
      _buildTab(Icons.network_check, 'Probe'),
      _buildTab(Icons.list_alt, 'Headers'),
      _buildTab(Icons.security, 'Security'),
      _buildTab(Icons.cookie_outlined, 'Cookies'),
    ];
  }

  List<Widget> _getTabViews(bool isHtmlOrXml, HtmlFile? currentFile) {
    return [
      // 1. Editor
      KeepAliveWrapper(
        child: currentFile != null
            ? FileViewer(
                file: currentFile,
                scrollController: _scrollController,
              )
            : const Center(child: Text('No File')),
      ),

      // 2. Metadata (Conditional)
      if (isHtmlOrXml) const KeepAliveWrapper(child: MetadataView()),

      // 3. Services (Conditional)
      if (isHtmlOrXml) const KeepAliveWrapper(child: ServicesView()),

      // 4. Media (Conditional)
      if (isHtmlOrXml) const KeepAliveWrapper(child: MediaView()),

      // 5. Probe: General
      const KeepAliveWrapper(child: ProbeGeneralView()),

      // 6. Probe: Headers
      const KeepAliveWrapper(child: ProbeHeadersView()),

      // 7. Probe: Security
      const KeepAliveWrapper(child: ProbeSecurityView()),

      // 8. Probe: Cookies
      const KeepAliveWrapper(child: ProbeCookiesView()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);

    // Update TabController synchronously if content type changed
    // This MUST happen before building the TabBar to avoid length mismatch
    if (htmlService.isHtmlOrXml != _lastIsHtmlOrXml) {
      _updateTabs(htmlService.isHtmlOrXml);
    }

    return Scaffold(
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
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            const UrlInput(),
            // The Toolbar with Navigation Tabs
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: _getTabs(htmlService.isHtmlOrXml),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: htmlService.currentFile == null
                  ? Padding(
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
                      ))
                  : TabBarView(
                      controller: _tabController,
                      children: _getTabViews(
                          htmlService.isHtmlOrXml, htmlService.currentFile),
                    ),
            ),
          ],
        ),
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
