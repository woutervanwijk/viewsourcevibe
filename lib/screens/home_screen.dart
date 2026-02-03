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
import 'package:view_source_vibe/widgets/dom_tree_view.dart';
import 'package:view_source_vibe/widgets/keep_alive_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _lastIsHtmlOrXml = false;
  bool _lastShowMetadataTabs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Use addPostFrameCallback to initialize correct length after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      _updateTabs(htmlService, force: true);
    });
  }

  void _handleTabSelection() {
    setState(() {
      // Rebuild to update FAB visibility based on _tabController.index
    });
  }

  void _updateTabs(HtmlService htmlService, {bool force = false}) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;

    if (isHtmlOrXml == _lastIsHtmlOrXml &&
        showMetadataTabs == _lastShowMetadataTabs &&
        !force) {
      return;
    }

    final oldIndex = _tabController.index;
    final oldLength = _tabController.length;

    // Calculate exact length: 1 (Editor) + 4 (Probe/Headers/Security/Cookies)
    // + (1 if isHtmlOrXml for DOM Tree)
    // + (3 if showMetadataTabs for Metadata/Services/Media)
    int newLength = 5;
    if (isHtmlOrXml) newLength += 1;
    if (showMetadataTabs) newLength += 3;

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
      _lastShowMetadataTabs = showMetadataTabs;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> _getTabs(HtmlService htmlService) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;

    return [
      _buildTab(Icons.code, 'Source'),
      if (showMetadataTabs) _buildTab(Icons.info_outline, 'Metadata'),
      if (showMetadataTabs) _buildTab(Icons.layers_outlined, 'Services'),
      if (showMetadataTabs) _buildTab(Icons.perm_media_outlined, 'Media'),
      if (isHtmlOrXml) _buildTab(Icons.account_tree_outlined, 'DOM Tree'),
      _buildTab(Icons.network_check, 'Probe'),
      _buildTab(Icons.list_alt, 'Headers'),
      _buildTab(Icons.security, 'Security'),
      _buildTab(Icons.cookie_outlined, 'Cookies'),
    ];
  }

  List<Widget> _getTabViews(HtmlService htmlService, HtmlFile? currentFile) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;

    return [
      // 1. Editor
      KeepAliveWrapper(
        child: currentFile != null
            ? FileViewer(
                file: currentFile,
              )
            : const Center(child: Text('No File')),
      ),

      // 2. Metadata (Conditional)
      if (showMetadataTabs) const KeepAliveWrapper(child: MetadataView()),

      // 3. Services (Conditional)
      if (showMetadataTabs) const KeepAliveWrapper(child: ServicesView()),

      // 4. Media (Conditional)
      if (showMetadataTabs) const KeepAliveWrapper(child: MediaView()),

      // 5. DOM Tree (Conditional)
      if (isHtmlOrXml) const KeepAliveWrapper(child: DomTreeView()),

      // 6. Probe: General
      const KeepAliveWrapper(child: ProbeGeneralView()),

      // 7. Probe: Headers
      const KeepAliveWrapper(child: ProbeHeadersView()),

      // 8. Probe: Security
      const KeepAliveWrapper(child: ProbeSecurityView()),

      // 9. Probe: Cookies
      const KeepAliveWrapper(child: ProbeCookiesView()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);

    // Update TabController synchronously if content type changed
    // This MUST happen before building the TabBar to avoid length mismatch
    if (htmlService.isHtmlOrXml != _lastIsHtmlOrXml ||
        htmlService.showMetadataTabs != _lastShowMetadataTabs) {
      _updateTabs(htmlService);
    }

    // Handle requested tab switch
    if (htmlService.requestedTabIndex != null) {
      final targetIndex = htmlService.requestedTabIndex!;
      if (targetIndex < _tabController.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tabController.animateTo(targetIndex);
        });
      }
      htmlService.consumeTabSwitchRequest();
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
        behavior: HitTestBehavior.translucent,
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
                tabs: _getTabs(htmlService),
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
                      children:
                          _getTabViews(htmlService, htmlService.currentFile),
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
