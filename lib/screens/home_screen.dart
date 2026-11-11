import 'package:flutter/material.dart';
import 'package:view_source_vibe/widgets/analysis_disclaimer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/widgets/source_viewer.dart';
import 'package:view_source_vibe/widgets/toolbar.dart';
import 'package:view_source_vibe/widgets/url_input.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';
import 'package:view_source_vibe/widgets/page_size_view.dart';
import 'package:view_source_vibe/widgets/services_view.dart';
import 'package:view_source_vibe/widgets/media_view.dart';
import 'package:view_source_vibe/widgets/privacy_view.dart';
import 'package:view_source_vibe/widgets/probe_views.dart';
import 'package:view_source_vibe/widgets/request_timeline_view.dart';
import 'package:view_source_vibe/widgets/sovereignty_view.dart';
import 'package:view_source_vibe/widgets/dom_tree_view.dart';
import 'package:view_source_vibe/widgets/keep_alive_wrapper.dart';
import 'package:view_source_vibe/widgets/browser_view.dart';
import 'package:view_source_vibe/widgets/reader_view.dart';
import 'package:view_source_vibe/services/reader_service.dart';

/// Key of the [HomeScreen]; the Cmd/Ctrl+arrow shortcuts switch its tabs.
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Times the tab structure was (re)built; tests check that a progress tick
  /// does not rebuild the tab bodies.
  @visibleForTesting
  static int structureBuilds = 0;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _tabScrollController = TabBarScrollController();
  bool _lastIsHtmlOrXml = false;
  bool _lastShowMetadataTabs = false;
  bool _lastShowServerTabs = false;
  bool _lastIsBrowserSupported = true;
  bool _lastShouldShowBrowser = true;
  int _lastBrowserTabIndex = -1;
  List<String> _tabLabels = const [];
  List<String> _tabTags = const [];

  /// Label of the tab the user is on. Tabs come and go while a page loads,
  /// so the selection follows the tab itself, not its index.
  String? _selectedTabLabel;
  String? _selectedTabTag;

  /// One focus node per tab tag, attached inside each [TabPageWrapper]. When
  /// a tab is selected its node gets keyboard focus, so PageUp/PageDown (and
  /// on web, the arrow keys) scroll the page without tapping it first.
  final Map<String, FocusNode> _tabFocusNodes = {};

  bool _tabRequestScheduled = false;

  FocusNode _tabFocusNode(String tag) => _tabFocusNodes.putIfAbsent(
      tag, () => FocusNode(debugLabel: 'tab-page-$tag'));

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
    // Guard against firing during the animation (indexIsChanging is true mid-swipe).
    // Only act once the destination tab is settled.
    if (_tabController.indexIsChanging) return;
    if (_tabController.index < _tabLabels.length) {
      _selectedTabLabel = _tabLabels[_tabController.index];
      _selectedTabTag =
          _tabTags.isNotEmpty && _tabController.index < _tabTags.length
              ? _tabTags[_tabController.index]
              : null;
    }

    final htmlService = Provider.of<HtmlService>(context, listen: false);
    htmlService.setActiveTabIndex(_tabController.index);

    // If switching to Browser tab, trigger reload if needed
    if (_tabController.index == htmlService.browserTabIndex) {
      htmlService.triggerBrowserReload().ignore();
    }

    _focusSelectedTabPage();
  }

  /// Focus the page of the tab that was just selected (tap or keyboard), so
  /// the keyboard scrolls it right away. Runs a frame later: tapping the tab
  /// strip also triggers the body tap handler, which unfocuses — the page
  /// focus has to win over that. The selected page may be built a frame after
  /// the tab settles, so the focus attempt retries a few frames.
  void _focusSelectedTabPage() {
    final tag = _selectedTabTag;
    final index = _tabController.index;
    if (tag == null) return;
    final htmlService = Provider.of<HtmlService>(context, listen: false);

    void attempt(int triesLeft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tabController.index != index) return;
        // Browser and Reader tabs render a WebView: hand keyboard focus to the
        // web page itself, so arrows/space scroll it natively.
        if (index == htmlService.browserTabIndex) {
          final controller = htmlService.activeWebViewController;
          if (controller != null) {
            controller.requestFocus().ignore();
            return;
          }
        }
        if (htmlService.isHtml && index == htmlService.readerTabIndex) {
          final controller = htmlService.readerService?.viewController;
          if (controller != null) {
            controller.requestFocus().ignore();
            return;
          }
        }
        final node = _tabFocusNodes[tag];
        if (node == null) return;
        if (node.context != null) {
          node.requestFocus();
        } else if (triesLeft > 0) {
          attempt(triesLeft - 1);
        }
      });
    }

    attempt(10);
  }

  /// Focus node of the currently selected tab page; tests check keyboard
  /// focus lands on it after a tab switch.
  @visibleForTesting
  FocusNode? get activeTabFocusNode {
    final index = _tabController.index;
    if (index < 0 || index >= _tabTags.length) return null;
    return _tabFocusNodes[_tabTags[index]];
  }

  void _updateTabs(HtmlService htmlService, {bool force = false}) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final shouldShowBrowser = htmlService.shouldShowBrowserTab;
    final browserTabIndex = htmlService.browserTabIndex;

    if (isHtmlOrXml == _lastIsHtmlOrXml &&
        showMetadataTabs == _lastShowMetadataTabs &&
        showServerTabs == _lastShowServerTabs &&
        isBrowserSupported == _lastIsBrowserSupported &&
        shouldShowBrowser == _lastShouldShowBrowser &&
        browserTabIndex == _lastBrowserTabIndex &&
        !force) {
      return;
    }

    final oldIndex = _tabController.index;
    final specs = _tabSpecs(htmlService);
    final labels = [for (final (_, label, _) in specs) label];
    final tags = [for (final (_, _, tag) in specs) tag];

    if (!_listEquals(labels, _tabLabels) || force) {
      final newLength = labels.length;
      final keep =
          _selectedTabLabel == null ? -1 : labels.indexOf(_selectedTabLabel!);
      _tabController.removeListener(_handleTabSelection);
      // We don't dispose here if called during build to avoid issues
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: keep >= 0 ? keep : oldIndex.clamp(0, newLength - 1),
      );
      _tabController.addListener(_handleTabSelection);
      _tabLabels = labels;
      _tabTags = tags;
      _lastIsHtmlOrXml = isHtmlOrXml;
      _lastShowMetadataTabs = showMetadataTabs;
      _lastShowServerTabs = showServerTabs;
      _lastIsBrowserSupported = isBrowserSupported;
      _lastShouldShowBrowser = shouldShowBrowser;
      _lastBrowserTabIndex = browserTabIndex;
      if (keep >= 0) {
        // Called during build: notify the service after this frame.
        WidgetsBinding.instance
            .addPostFrameCallback((_) => htmlService.setActiveTabIndex(keep));
      }
    }
  }

  static bool _listEquals(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  @override
  void dispose() {
    _tabController.dispose();
    _tabScrollController.dispose();
    for (final node in _tabFocusNodes.values) {
      node.dispose();
    }
    _tabFocusNodes.clear();
    super.dispose();
  }

  /// Switch one tab left/right, wrapping around (Cmd/Ctrl+ArrowLeft/Right).
  void switchTab(int delta) {
    final count = _tabController.length;
    if (count < 2) return;
    var index = (_tabController.index + delta) % count;
    if (index < 0) index += count;
    _tabController.animateTo(index);
  }

  /// Current tab index; tests check keyboard tab switching with it.
  @visibleForTesting
  int get currentTabIndex => _tabController.index;

  /// Horizontal offset of the tab strip; tests check wheel scrolling with it.
  @visibleForTesting
  double get tabStripOffset => _tabScrollController.hasClients
      ? _tabScrollController.position.pixels
      : 0;

  /// A mouse wheel over the tab strip scrolls it horizontally. The strip is
  /// a horizontal scrollable, which by default only follows dx (trackpad),
  /// not the wheel's dy — so on macOS/Windows the wheel did nothing here.
  void _onTabStripPointerSignal(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent) return;
    final dy = signal.scrollDelta.dy;
    if (dy == 0 || signal.scrollDelta.dx != 0) return;
    // With an axis-flip modifier (e.g. shift) the built-in handling already
    // maps the wheel onto the horizontal axis.
    final modifiers = ScrollConfiguration.of(context).pointerAxisModifiers;
    if (HardwareKeyboard.instance.logicalKeysPressed.any(modifiers.contains)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(signal, (_) {
      if (_tabScrollController.hasClients) {
        _tabScrollController.position.pointerScroll(dy);
      }
    });
  }

  Future<void> _handleRefresh() async {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    await htmlService.refresh(switchToTab: _tabController.index);
  }

  Widget _buildRefreshable(Widget child, String tag) {
    final page = TabPageWrapper(
      tag: tag,
      focusNode: _tabFocusNode(tag),
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: child,
      ),
    );
    // Analysis tabs get the disclaimer; browser, reader, source and DOM tree
    // show the page itself.
    if (const {'browser-content', 'reader', 'source', 'dom-tree'}.contains(tag)) {
      return page;
    }
    return Column(
      children: [Expanded(child: page), const AnalysisDisclaimer()],
    );
  }

  Widget _buildScrollableRefreshable(Widget child, String tag,
      {bool hasScrollBody = true, bool useSliverToBoxAdapter = false}) {
    return TabPageWrapper(
      tag: tag,
      focusNode: _tabFocusNode(tag),
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          shrinkWrap: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (useSliverToBoxAdapter)
              SliverToBoxAdapter(child: child)
            else if (hasScrollBody)
              SliverFillRemaining(
                hasScrollBody: true,
                child: child,
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  /// Tabs in display order as (icon, label, page tag). The tags match the
  /// [TabPageWrapper] tags in [_getTabViews]; both lists are kept in sync.
  List<(IconData, String, String)> _tabSpecs(HtmlService htmlService) {
    final isHtml = htmlService.isHtml;
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;
    final shouldShowBrowser =
        isBrowserSupported && htmlService.shouldShowBrowserTab;
    const browserTab = (Icons.language, 'Browser', 'browser');

    return [
      if (shouldShowBrowser && useBrowserByDefault) browserTab,
      if (showMetadataTabs) ...[
        (Icons.info_outline, 'Metadata', 'metadata'),
        (Icons.perm_media_outlined, 'Media', 'media'),
        (Icons.scale_outlined, 'Size', 'page-size'),
        (Icons.layers_outlined, 'Services', 'services'),
        (Icons.privacy_tip_outlined, 'Privacy', 'privacy'),
        if (showServerTabs) (Icons.public, 'Sovereignty', 'sovereignty'),
      ],
      if (isHtml) (Icons.chrome_reader_mode, 'Reader', 'reader'),
      if (isHtmlOrXml) (Icons.account_tree_outlined, 'DOM Tree', 'dom-tree'),
      (Icons.code, 'Source', 'source'),
      if (showServerTabs) ...[
        (Icons.cookie_outlined, 'Cookies', 'cookies'),
        (Icons.timeline, 'Timeline', 'request-timeline'),
        (Icons.network_check, 'Probe', 'probe'),
        (Icons.list_alt, 'Headers', 'headers'),
        (Icons.security, 'Security', 'security'),
        if (!showMetadataTabs) (Icons.public, 'Sovereignty', 'sovereignty'),
      ],
      // When 'Always use browser' is off, Browser tab goes last
      if (shouldShowBrowser && !useBrowserByDefault) browserTab,
    ];
  }

  List<Widget> _getTabs(HtmlService htmlService) => [
        for (final (icon, label, _) in _tabSpecs(htmlService))
          _buildTab(icon, label),
      ];

  List<Widget> _getTabViews(HtmlService htmlService, HtmlFile? currentFile) {
    final isHtml = htmlService.isHtml;
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final showMetadataTabs = htmlService.showMetadataTabs;
    final showServerTabs = htmlService.showServerTabs;
    final isBrowserSupported = htmlService.isBrowserSupported;
    final useBrowserByDefault = htmlService.browserTabIndex == 0;
    final shouldShowBrowser = htmlService.shouldShowBrowserTab;

    final sourceView = currentFile != null
        ? KeepAliveWrapper(
            key: const ValueKey('tab_source'),
            child: _buildRefreshable(
              SourceViewer(
                key: const ValueKey('file_viewer_source'),
                file: currentFile,
              ),
              'source',
            ),
          )
        : _buildScrollableRefreshable(
            Center(
                key: const ValueKey('tab_source_empty'),
                child: htmlService.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('No File')),
            'no-file',
          );

    final browserView = TabPageWrapper(
      key: const ValueKey('tab_browser'),
      tag: 'browser',
      focusNode: _tabFocusNode('browser'),
      isBrowserTab: true,
      child: KeepAliveWrapper(
        child: _buildRefreshable(
          (currentFile != null &&
                      (currentFile.isUrl ||
                          isHtmlOrXml ||
                          useBrowserByDefault)) ||
                  htmlService.shouldShowBrowserTab
              ? BrowserView(
                  key: const ValueKey('browser_view'),
                  file: currentFile,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                  },
                )
              : (htmlService.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text('Not available for this file'))),
          'browser-content',
        ),
      ),
    );

    final readerView = KeepAliveWrapper(
      key: const ValueKey('tab_reader'),
      child: _buildRefreshable(
        ReaderView(
          gestureRecognizers: {
            Factory<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(),
            ),
          },
        ),
        'reader',
      ),
    );

    if (!isBrowserSupported) {
      return [
        if (showMetadataTabs) ...[
          KeepAliveWrapper(
              child: _buildRefreshable(const MetadataView(), 'metadata')),
          KeepAliveWrapper(
              child: _buildRefreshable(const MediaView(), 'media')),
          KeepAliveWrapper(
              child: _buildRefreshable(const PageSizeView(), 'page-size')),
          KeepAliveWrapper(
              child: _buildRefreshable(const ServicesView(), 'services')),
          KeepAliveWrapper(
              child: _buildRefreshable(const PrivacyView(), 'privacy')),
          if (showServerTabs)
            KeepAliveWrapper(
                child:
                    _buildRefreshable(const SovereigntyView(), 'sovereignty')),
        ],
        if (isHtml) readerView,
        if (isHtmlOrXml)
          KeepAliveWrapper(
              child: _buildRefreshable(const DomTreeView(), 'dom-tree')),
        sourceView,
        if (showServerTabs)
          KeepAliveWrapper(
              child: _buildRefreshable(const ProbeCookiesView(), 'cookies')),
        if (showServerTabs) ...[
          KeepAliveWrapper(
              child: _buildRefreshable(
                  const RequestTimelineView(), 'request-timeline')),
          KeepAliveWrapper(
              child: _buildRefreshable(const ProbeGeneralView(), 'probe')),
          KeepAliveWrapper(
              child: _buildRefreshable(const ProbeHeadersView(), 'headers')),
          KeepAliveWrapper(
              child: _buildRefreshable(const ProbeSecurityView(), 'security')),
          if (!showMetadataTabs)
            KeepAliveWrapper(
                child:
                    _buildRefreshable(const SovereigntyView(), 'sovereignty')),
        ],
      ];
    }

    return [
      if (shouldShowBrowser && useBrowserByDefault) browserView,
      if (showMetadataTabs) ...[
        KeepAliveWrapper(
            key: const ValueKey('tab_metadata'),
            child: _buildRefreshable(const MetadataView(), 'metadata')),
        KeepAliveWrapper(
            key: const ValueKey('tab_media'),
            child: _buildRefreshable(const MediaView(), 'media')),
        KeepAliveWrapper(
            key: const ValueKey('tab_page_size'),
            child: _buildRefreshable(const PageSizeView(), 'page-size')),
        KeepAliveWrapper(
            key: const ValueKey('tab_services'),
            child: _buildRefreshable(const ServicesView(), 'services')),
        KeepAliveWrapper(
            key: const ValueKey('tab_privacy'),
            child: _buildRefreshable(const PrivacyView(), 'privacy')),
        if (showServerTabs)
          KeepAliveWrapper(
              key: const ValueKey('tab_sovereignty'),
              child: _buildRefreshable(const SovereigntyView(), 'sovereignty')),
      ],

      // Reader, DOM Tree and Source sit right of the metadata tabs
      if (isHtml) readerView,
      if (isHtmlOrXml)
        KeepAliveWrapper(
            key: const ValueKey('tab_dom_tree'),
            child: _buildRefreshable(const DomTreeView(), 'dom-tree')),
      sourceView,

      // 6. Probe: Cookies
      if (showServerTabs)
        KeepAliveWrapper(
            key: const ValueKey('tab_cookies'),
            child: _buildRefreshable(const ProbeCookiesView(), 'cookies')),

      // 7-10. Probe: Timeline, General, Headers, Security
      if (showServerTabs) ...[
        KeepAliveWrapper(
            key: const ValueKey('tab_timeline'),
            child: _buildRefreshable(
                const RequestTimelineView(), 'request-timeline')),
        KeepAliveWrapper(
            key: const ValueKey('tab_probe'),
            child: _buildRefreshable(const ProbeGeneralView(), 'probe')),
        KeepAliveWrapper(
            key: const ValueKey('tab_headers'),
            child: _buildRefreshable(const ProbeHeadersView(), 'headers')),
        KeepAliveWrapper(
            key: const ValueKey('tab_security'),
            child: _buildRefreshable(const ProbeSecurityView(), 'security')),
        if (!showMetadataTabs)
          KeepAliveWrapper(
              key: const ValueKey('tab_sovereignty'),
              child: _buildRefreshable(const SovereigntyView(), 'sovereignty')),
      ],

      // When 'Always use browser' is off, Browser tab goes last
      if (shouldShowBrowser && !useBrowserByDefault) browserView,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Use listen: false to prevent the entire HomeScreen from rebuilding
    // on every single change (like webViewLoadingProgress).
    // We use Selector below to only rebuild when relevant parts change.
    final htmlService = Provider.of<HtmlService>(context, listen: false);

    return Selector<HtmlService, _HomeScreenStructure>(
      selector: (context, service) => _HomeScreenStructure(
        isHtml: service.isHtml,
        isHtmlOrXml: service.isHtmlOrXml,
        showMetadataTabs: service.showMetadataTabs,
        showServerTabs: service.showServerTabs,
        isBrowserSupported: service.isBrowserSupported,
        shouldShowBrowserTab: service.shouldShowBrowserTab,
        browserTabIndex: service.browserTabIndex,
        currentFile: service.currentFile,
        isLoading: service.isLoading,
        requestedTabIndex: service.requestedTabIndex,
      ),
      builder: (context, structure, child) {
        HomeScreen.structureBuilds++;
        // Update TabController synchronously if content type changed
        // This MUST happen before building the TabBar to avoid length mismatch
        if (structure.isHtmlOrXml != _lastIsHtmlOrXml ||
            structure.showMetadataTabs != _lastShowMetadataTabs ||
            structure.showServerTabs != _lastShowServerTabs ||
            structure.isBrowserSupported != _lastIsBrowserSupported ||
            structure.shouldShowBrowserTab != _lastShouldShowBrowser ||
            structure.browserTabIndex != _lastBrowserTabIndex) {
          _updateTabs(htmlService);
        }

        // Handle requested tab switch (never mutate the service in build).
        if (structure.requestedTabIndex != null && !_tabRequestScheduled) {
          _tabRequestScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabRequestScheduled = false;
            if (!mounted) return;
            final requested = htmlService.requestedTabIndex;
            if (requested == null) return;
            final targetIndex = htmlService.resolveTabRequest(requested);
            htmlService.consumeTabSwitchRequest();
            if (targetIndex < _tabController.length) {
              _tabController.animateTo(targetIndex);
            }
          });
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            final htmlService =
                Provider.of<HtmlService>(context, listen: false);
            if (htmlService.canGoBack) {
              htmlService.goBack();
            } else {
              // Default behavior: exit app if at root
              final NavigatorState navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                await SystemChannels.platform
                    .invokeMethod('SystemNavigator.pop');
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
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
                  const SizedBox(width: 8),
                  const ToolbarBackButton(),
                ],
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
                  UrlInput(key: urlInputKey),
                  // The Toolbar with Navigation Tabs
                  Listener(
                    onPointerSignal: _onTabStripPointerSignal,
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        controller: _tabController,
                        scrollController: _tabScrollController,
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
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child:
                        (structure.currentFile == null && !structure.isLoading)
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
                                    htmlService, structure.currentFile),
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

/// Helper class to track structure-defining state for HomeScreen
@immutable
class _HomeScreenStructure {
  final bool isHtml;
  final bool isHtmlOrXml;
  final bool showMetadataTabs;
  final bool showServerTabs;
  final bool isBrowserSupported;
  final bool shouldShowBrowserTab;
  final int browserTabIndex;
  final HtmlFile? currentFile;
  final bool isLoading;
  final int? requestedTabIndex;

  const _HomeScreenStructure({
    required this.isHtml,
    required this.isHtmlOrXml,
    required this.showMetadataTabs,
    required this.showServerTabs,
    required this.isBrowserSupported,
    required this.shouldShowBrowserTab,
    required this.browserTabIndex,
    this.currentFile,
    required this.isLoading,
    this.requestedTabIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HomeScreenStructure &&
          runtimeType == other.runtimeType &&
          isHtml == other.isHtml &&
          isHtmlOrXml == other.isHtmlOrXml &&
          showMetadataTabs == other.showMetadataTabs &&
          showServerTabs == other.showServerTabs &&
          isBrowserSupported == other.isBrowserSupported &&
          shouldShowBrowserTab == other.shouldShowBrowserTab &&
          browserTabIndex == other.browserTabIndex &&
          currentFile == other.currentFile &&
          isLoading == other.isLoading &&
          requestedTabIndex == other.requestedTabIndex;

  @override
  int get hashCode =>
      isHtml.hashCode ^
      isHtmlOrXml.hashCode ^
      showMetadataTabs.hashCode ^
      showServerTabs.hashCode ^
      isBrowserSupported.hashCode ^
      shouldShowBrowserTab.hashCode ^
      browserTabIndex.hashCode ^
      currentFile.hashCode ^
      isLoading.hashCode ^
      requestedTabIndex.hashCode;
}

class TabPageWrapper extends StatefulWidget {
  final Widget child;
  final bool isBrowserTab;
  final String tag;
  /// Focus node for the page; HomeScreen requests focus on it when this tab
  /// is selected, so the page scrolls with the keyboard. Placed inside the
  /// [PrimaryScrollController] so scroll key events reach the page's
  /// scrollable via the primary controller.
  final FocusNode? focusNode;
  const TabPageWrapper({
    super.key,
    required this.child,
    required this.tag,
    this.isBrowserTab = false,
    this.focusNode,
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
      htmlService.activeWebViewController?.scrollTo(x: 0, y: 0);
    }

    // 2b. Reader tab's own WebView
    Provider.of<ReaderService>(context, listen: false).scrollToTop().ignore();

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
      child: Focus(
        focusNode: widget.focusNode,
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
      ),
    );
  }
}
