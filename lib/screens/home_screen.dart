import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  bool _lastShowServerTabs = false;
  bool _lastIsBrowserSupported = true;
  bool _lastShouldShowBrowser = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final shouldShowBrowser = (htmlService.currentFile?.isUrl ?? false) ||
        htmlService.isWebViewLoading;

    if (isHtmlOrXml == _lastIsHtmlOrXml &&
        showMetadataTabs == _lastShowMetadataTabs &&
        showServerTabs == _lastShowServerTabs &&
        isBrowserSupported == _lastIsBrowserSupported &&
        shouldShowBrowser == _lastShouldShowBrowser &&
        !force) {
      return;
    }

    final oldIndex = _tabController.index;
    final oldLength = _tabController.length;

    // Calculate exact length: 1 (Editor)
    // + (1 if isBrowserSupported AND shouldShowBrowser for Browser)
    // + (1 if isHtmlOrXml for DOM Tree)
    // + (3 if showMetadataTabs for Metadata/Services/Media)
    // + (4 if showServerTabs for Probe/Headers/Security/Cookies)
    int newLength = 1; // Editor
    if (isBrowserSupported && shouldShowBrowser) newLength += 1;
    if (isHtmlOrXml) newLength += 1;
    if (showMetadataTabs) newLength += 3;
    if (showServerTabs) newLength += 4;

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
      _lastShowServerTabs = showServerTabs;
      _lastIsBrowserSupported = isBrowserSupported;
      _lastShouldShowBrowser = shouldShowBrowser;
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

  Widget _buildRefreshable(Widget child, String tag) {
    return TabPageWrapper(
      tag: tag,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: child,
      ),
    );
  }

  Widget _buildScrollableRefreshable(Widget child, String tag,
      {bool hasScrollBody = true}) {
    return TabPageWrapper(
      tag: tag,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (hasScrollBody)
              SliverFillRemaining(
                hasScrollBody: true,
                child: child,
              )
            else
              SliverToBoxAdapter(
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
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;
    final shouldShowBrowser = (htmlService.currentFile?.isUrl ?? false) ||
        htmlService.isWebViewLoading;

    final sourceTab = _buildTab(Icons.code, 'Source');
    final browserTab = _buildTab(Icons.language, 'Browser');

    if (!isBrowserSupported) {
      return [
        sourceTab,
        if (isHtmlOrXml) _buildTab(Icons.account_tree_outlined, 'DOM Tree'),
        if (showMetadataTabs) _buildTab(Icons.info_outline, 'Metadata'),
        if (showMetadataTabs) _buildTab(Icons.layers_outlined, 'Services'),
        if (showMetadataTabs) _buildTab(Icons.perm_media_outlined, 'Media'),
        if (showServerTabs) _buildTab(Icons.cookie_outlined, 'Cookies'),
        if (showServerTabs) ...[
          _buildTab(Icons.network_check, 'Probe'),
          _buildTab(Icons.list_alt, 'Headers'),
          _buildTab(Icons.security, 'Security'),
        ],
      ];
    }

    return [
      if (shouldShowBrowser && useBrowserByDefault) browserTab,
      sourceTab,
      if (shouldShowBrowser && !useBrowserByDefault) browserTab,
      if (isHtmlOrXml) _buildTab(Icons.account_tree_outlined, 'DOM Tree'),
      if (showMetadataTabs) _buildTab(Icons.info_outline, 'Metadata'),
      if (showMetadataTabs) _buildTab(Icons.layers_outlined, 'Services'),
      if (showMetadataTabs) _buildTab(Icons.perm_media_outlined, 'Media'),
      if (showServerTabs) _buildTab(Icons.cookie_outlined, 'Cookies'),
      if (showServerTabs) ...[
        _buildTab(Icons.network_check, 'Probe'),
        _buildTab(Icons.list_alt, 'Headers'),
        _buildTab(Icons.security, 'Security'),
      ],
    ];
  }

  List<Widget> _getTabViews(HtmlService htmlService, HtmlFile? currentFile) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;
    final shouldShowBrowser =
        (currentFile?.isUrl ?? false) || htmlService.isWebViewLoading;

    final sourceView = currentFile != null
        ? _buildRefreshable(
            FileViewer(
              file: currentFile,
            ),
            'source',
          )
        : _buildScrollableRefreshable(
            Center(
                child: htmlService.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('No File')),
            'no-file',
          );

    final browserView = TabPageWrapper(
      tag: 'browser',
      isBrowserTab: true,
      child: KeepAliveWrapper(
        child: _buildRefreshable(
          (currentFile != null &&
                      (currentFile.isUrl ||
                          isHtmlOrXml ||
                          useBrowserByDefault)) ||
                  htmlService.isWebViewLoading
              ? BrowserView(
                  file: currentFile,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer()),
                  },
                )
              : (htmlService.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text('Not available for this file'))),
          'browser-content',
        ),
      ),
    );

    if (!isBrowserSupported) {
      return [
        sourceView,
        if (isHtmlOrXml)
          KeepAliveWrapper(
              child: _buildRefreshable(const DomTreeView(), 'dom-tree')),
        if (showMetadataTabs)
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const MetadataView(), 'metadata',
                  hasScrollBody: false)),
        if (showMetadataTabs)
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const ServicesView(), 'services',
                  hasScrollBody: false)),
        if (showMetadataTabs)
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(const MediaView(), 'media',
                  hasScrollBody: false)),
        if (showServerTabs)
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const ProbeCookiesView(), 'cookies')),
        if (showServerTabs) ...[
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const ProbeGeneralView(), 'probe')),
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const ProbeHeadersView(), 'headers')),
          KeepAliveWrapper(
              child: _buildScrollableRefreshable(
                  const ProbeSecurityView(), 'security')),
        ],
      ];
    }

    return [
      if (shouldShowBrowser && useBrowserByDefault) browserView,
      sourceView,
      if (shouldShowBrowser && !useBrowserByDefault) browserView,

      // 3. DOM Tree (Conditional)
      if (isHtmlOrXml)
        KeepAliveWrapper(
            child: _buildRefreshable(const DomTreeView(), 'dom-tree')),

      // 3. Metadata (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const MetadataView(), 'metadata',
                hasScrollBody: false)),

      // 4. Services (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const ServicesView(), 'services',
                hasScrollBody: false)),

      // 5. Media (Conditional)
      if (showMetadataTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(const MediaView(), 'media',
                hasScrollBody: false)),

      // 6. Probe: Cookies
      if (showServerTabs)
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(
                const ProbeCookiesView(), 'cookies')),

      // 7. Probe: General
      if (showServerTabs) ...[
        KeepAliveWrapper(
            child:
                _buildScrollableRefreshable(const ProbeGeneralView(), 'probe')),

        // 8. Probe: Headers
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(
                const ProbeHeadersView(), 'headers')),

        // 9. Probe: Security
        KeepAliveWrapper(
            child: _buildScrollableRefreshable(
                const ProbeSecurityView(), 'security')),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);

    // Update TabController synchronously if content type changed
    // This MUST happen before building the TabBar to avoid length mismatch
    final shouldShowBrowser = (htmlService.currentFile?.isUrl ?? false) ||
        htmlService.isWebViewLoading;

    if (htmlService.isHtmlOrXml != _lastIsHtmlOrXml ||
        htmlService.showMetadataTabs != _lastShowMetadataTabs ||
        htmlService.showServerTabs != _lastShowServerTabs ||
        htmlService.isBrowserSupported != _lastIsBrowserSupported ||
        shouldShowBrowser != _lastShouldShowBrowser) {
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
                child: (htmlService.currentFile == null &&
                        !htmlService.isLoading)
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
  final bool isBrowserTab;
  final String tag;
  const TabPageWrapper({
    super.key,
    required this.child,
    required this.tag,
    this.isBrowserTab = false,
  });

  @override
  State<TabPageWrapper> createState() => _TabPageWrapperState();
}

class _TabPageWrapperState extends State<TabPageWrapper> {
  final ScrollController _controller = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_controller.hasClients) {
      if (_controller.offset > 200 && !_showFab) {
        setState(() => _showFab = true);
      } else if (_controller.offset <= 200 && _showFab) {
        setState(() => _showFab = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    _controller.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    // 1. Regular scrolling for the tab wrapper or primary scroll controller
    if (_controller.hasClients) {
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 2. Specialized handling for WebView in BrowserView
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    if (htmlService.activeWebViewController != null) {
      // WebView scroll to top (internal content)
      htmlService.activeWebViewController?.scrollTo(0, 0);
    }

    // 3. Fallback: also try PrimaryScrollController if it's different
    final primary = PrimaryScrollController.of(context);
    if (primary.hasClients && primary != _controller) {
      primary.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          if (widget.isBrowserTab)
            // For Browser Tab, listen to the ValueNotifier from HtmlService
            // This prevents the entire HomeScreen from rebuilding on every scroll pixel
            ValueListenableBuilder<double>(
              valueListenable: Provider.of<HtmlService>(context, listen: false)
                  .webViewScrollNotifier,
              builder: (context, scrollY, _) {
                if (scrollY > 200) {
                  return Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: 'scroll-to-top-${widget.tag}',
                      mini: true,
                      onPressed: _scrollToTop,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.arrow_upward),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          else
          // For other tabs, use local state
          if (_showFab)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'scroll-to-top-${widget.tag}',
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.arrow_upward),
              ),
            ),
        ],
      ),
    );
  }
}
