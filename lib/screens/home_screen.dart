import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:view_source_vibe/widgets/browser_view.dart';

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
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Use addPostFrameCallback to initialize correct length after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      _updateTabs(htmlService, force: true);
    });
  }

  void _handleTabSelection() {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    htmlService.setActiveTabIndex(_tabController.index);

    // If switching to Browser tab, trigger reload if needed
    if (_tabController.index == htmlService.browserTabIndex) {
      htmlService.triggerBrowserReload().ignore();
    }

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

    // Calculate exact length: 1 (Editor) + 1 (Browser) + 4 (Probe/Headers/Security/Cookies)
    // + (1 if isHtmlOrXml for DOM Tree)
    // + (3 if showMetadataTabs for Metadata/Services/Media)
    int newLength = 6;
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

  Future<void> _handleRefresh() async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    final url = htmlService.currentInputText;
    if (url != null && url.isNotEmpty) {
      await htmlService.loadUrl(url, switchToTab: _tabController.index);
    }
  }

  Widget _buildRefreshable(Widget child) {
    return TabPageWrapper(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: child,
      ),
    );
  }

  Widget _buildScrollableRefreshable(Widget child) {
    return TabPageWrapper(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: true,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getTabs(HtmlService htmlService) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;

    final sourceTab = _buildTab(Icons.code, 'Source');
    final browserTab = _buildTab(Icons.language, 'Browser');

    return [
      if (useBrowserByDefault) browserTab else sourceTab,
      if (useBrowserByDefault) sourceTab else browserTab,
      if (isHtmlOrXml) _buildTab(Icons.account_tree_outlined, 'DOM Tree'),
      if (showMetadataTabs) _buildTab(Icons.info_outline, 'Metadata'),
      if (showMetadataTabs) _buildTab(Icons.layers_outlined, 'Services'),
      if (showMetadataTabs) _buildTab(Icons.perm_media_outlined, 'Media'),
      _buildTab(Icons.network_check, 'Probe'),
      _buildTab(Icons.list_alt, 'Headers'),
      _buildTab(Icons.security, 'Security'),
      _buildTab(Icons.cookie_outlined, 'Cookies'),
    ];
  }

  List<Widget> _getTabViews(HtmlService htmlService, HtmlFile? currentFile) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;

    final sourceView = KeepAliveWrapper(
      child: currentFile != null
          ? _buildRefreshable(
              FileViewer(
                file: currentFile,
              ),
            )
          : _buildScrollableRefreshable(
              const Center(child: Text('No File')),
            ),
    );

    final browserView = KeepAliveWrapper(
      child: _buildScrollableRefreshable(
        currentFile != null &&
                (currentFile.isUrl || isHtmlOrXml || useBrowserByDefault)
            ? BrowserView(file: currentFile)
            : const Center(child: Text('Not available for this file')),
      ),
    );

    return [
      if (useBrowserByDefault) browserView else sourceView,
      if (useBrowserByDefault) sourceView else browserView,

      // 3. DOM Tree (Conditional)
      if (isHtmlOrXml)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const DomTreeView())),

      // 3. Metadata (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const MetadataView())),

      // 4. Services (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const ServicesView())),

      // 5. Media (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(child: _buildScrollableRefreshable(const MediaView())),

      // 6. Probe: General
      KeepAliveWrapper(
          child: _buildScrollableRefreshable(const ProbeGeneralView())),

      // 7. Probe: Headers
      KeepAliveWrapper(
          child: _buildScrollableRefreshable(const ProbeHeadersView())),

      // 8. Probe: Security
      KeepAliveWrapper(
          child: _buildScrollableRefreshable(const ProbeSecurityView())),

      // 9. Probe: Cookies
      KeepAliveWrapper(
          child: _buildScrollableRefreshable(const ProbeCookiesView())),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final htmlService = Provider.of<HtmlService>(context, listen: false);
        if (htmlService.canGoBack) {
          htmlService.goBack();
        } else {
          // Default behavior: exit app if at root
          final NavigatorState navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        }
      },
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

class TabPageWrapper extends StatefulWidget {
  final Widget child;
  const TabPageWrapper({super.key, required this.child});

  @override
  State<TabPageWrapper> createState() => _TabPageWrapperState();
}

class _TabPageWrapperState extends State<TabPageWrapper> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}
