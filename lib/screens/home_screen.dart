import 'package:flutter/material.dart';
import 'package:view_source_vibe/widgets/analysis_disclaimer.dart';
import 'package:view_source_vibe/widgets/block_page_banner.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/about_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/models/app_tab.dart';
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
  final _tabScrollController = ScrollController();

  /// The tabs on screen, in order; the TabController indexes into this list.
  List<AppTab> _tabs = const [];
  List<String> _tabLabels = const [];
  List<String> _tabTags = const [];

  /// Last tab the user had open in each group, so tapping a group returns
  /// there instead of always to its first tab.
  final Map<TabGroup, AppTab> _lastTabInGroup = {};

  /// Key of the selected chip, scrolled into view when the tab changes.
  final _selectedChipKey = GlobalKey();

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
      if (!mounted) return;
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      // Rebuild, so the tab bar and pages use the new controller.
      setState(() => _updateTabs(htmlService, force: true));
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
    if (_tabController.index < _tabs.length) {
      final tab = _tabs[_tabController.index];
      _lastTabInGroup[tab.group] = tab;
    }
    _revealSelectedChip();

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

  /// Rebuilds the TabController when the set of visible tabs changed. The
  /// selection follows the tab the user was on, wherever it moved.
  void _updateTabs(HtmlService htmlService, {bool force = false}) {
    final tabs = htmlService.visibleTabs;
    if (!force && listEquals(tabs, _tabs)) return;

    final oldIndex = _tabController.index;
    final newLength = tabs.length;
    final keep = _selectedTabLabel == null
        ? -1
        : tabs.indexWhere((t) => t.label == _selectedTabLabel);
    var initial = keep >= 0 ? keep : oldIndex.clamp(0, newLength - 1);
    // Without "Always use Browser" the Browser tab loads the page when it
    // shows, so the app never lands on it by itself; only a request (startup,
    // deep link) or the user opens it.
    if (keep < 0 &&
        !htmlService.useBrowserByDefault &&
        tabs[initial] == AppTab.browser &&
        newLength > 1) {
      initial = 1;
    }
    _tabController.removeListener(_handleTabSelection);
    // We don't dispose here if called during build to avoid issues
    _tabController = TabController(
      length: newLength,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(_handleTabSelection);
    _tabs = tabs;
    _tabLabels = [for (final t in tabs) t.label];
    _tabTags = [for (final t in tabs) t.tag];
    // Called during build: notify the service after this frame.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => htmlService.setActiveTabIndex(initial));
  }

  /// Tapping a group opens the tab last used in it, else its first tab.
  void _selectGroup(TabGroup group) {
    final last = _lastTabInGroup[group];
    final target = last != null && _tabs.contains(last)
        ? last
        : _tabs.firstWhere((t) => t.group == group);
    _tabController.animateTo(_tabs.indexOf(target));
  }

  /// Keep the selected chip visible in its (horizontally scrolling) row.
  void _revealSelectedChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chipContext = _selectedChipKey.currentContext;
      if (!mounted || chipContext == null) return;
      Scrollable.ensureVisible(chipContext,
          alignment: 0.5, duration: const Duration(milliseconds: 200));
    });
  }

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
    // Tabs that analyse the page content say so when it is a block page.
    const contentTabs = {
      'metadata',
      'media',
      'page-size',
      'services',
      'privacy',
      'sovereignty'
    };
    return Column(
      children: [
        if (contentTabs.contains(tag)) const BlockPageBanner(),
        Expanded(child: page),
        const AnalysisDisclaimer(),
      ],
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

  /// One page per tab in [_tabs], in the same order.
  List<Widget> _getTabViews(HtmlService htmlService, HtmlFile? currentFile) {
    final isHtmlOrXml = htmlService.isHtmlOrXml;
    final useBrowserByDefault = htmlService.useBrowserByDefault;

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

    Widget page(AppTab tab, Widget view) => KeepAliveWrapper(
        key: ValueKey('tab_${tab.tag}'),
        child: _buildRefreshable(view, tab.tag));

    return [
      for (final tab in _tabs)
        switch (tab) {
          AppTab.browser => browserView,
          AppTab.metadata => page(tab, const MetadataView()),
          AppTab.media => page(tab, const MediaView()),
          AppTab.services => page(tab, const ServicesView()),
          AppTab.reader => readerView,
          AppTab.domTree => page(tab, const DomTreeView()),
          AppTab.source => sourceView,
          AppTab.size => page(tab, const PageSizeView()),
          AppTab.headers => page(tab, const ProbeHeadersView()),
          AppTab.timeline => page(tab, const RequestTimelineView()),
          AppTab.probe => page(tab, const ProbeGeneralView()),
          AppTab.privacy => page(tab, const PrivacyView()),
          AppTab.sovereignty => page(tab, const SovereigntyView()),
          AppTab.security => page(tab, const ProbeSecurityView()),
          AppTab.cookies => page(tab, const ProbeCookiesView()),
        },
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
        tabs: service.visibleTabs,
        currentFile: service.currentFile,
        isLoading: service.isLoading,
        requestedTabIndex: service.requestedTabIndex,
      ),
      builder: (context, structure, child) {
        HomeScreen.structureBuilds++;
        // Update the TabController synchronously when the tabs changed. This
        // MUST happen before building the tab bar to avoid a length mismatch.
        _updateTabs(htmlService);

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
              title: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
                // Shrinks on very narrow screens instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/icon.webp',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'View Source Vibe',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
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
                  UrlInput(key: urlInputKey),
                  _buildTabGroupBar(context),
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

  /// Two-level tab bar: a group selector (Page · Code · Network · Trust) and
  /// a row of chips for the tabs of the selected group. The current tab
  /// decides the group, so swiping between pages moves across groups too.
  Widget _buildTabGroupBar(BuildContext context) {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        if (_tabs.isEmpty) return const SizedBox.shrink();
        final current = _tabs[_tabController.index.clamp(0, _tabs.length - 1)];
        final groups = [
          for (final g in TabGroup.values)
            if (_tabs.any((t) => t.group == g)) g,
        ];
        final groupTabs = [
          for (final t in _tabs)
            if (t.group == current.group) t,
        ];
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (groups.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TabGroup>(
                      segments: [
                        for (final g in groups)
                          ButtonSegment(value: g, label: Text(g.label)),
                      ],
                      selected: {current.group},
                      showSelectedIcon: false,
                      // Same corners as the chips below (Material 3: 8).
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                      ),
                      onSelectionChanged: (selection) =>
                          _selectGroup(selection.first),
                    ),
                  ),
                ),
              Listener(
                onPointerSignal: _onTabStripPointerSignal,
                child: SingleChildScrollView(
                  key: const ValueKey('tab-chip-strip'),
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                  child: Row(
                    children: [
                      for (final tab in groupTabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: tab == current ? _selectedChipKey : null,
                            avatar: Icon(tab.icon, size: 18),
                            label: Text(tab.label),
                            selected: tab == current,
                            showCheckmark: false,
                            onSelected: (_) =>
                                _tabController.animateTo(_tabs.indexOf(tab)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper class to track structure-defining state for HomeScreen
@immutable
class _HomeScreenStructure {
  final List<AppTab> tabs;
  final HtmlFile? currentFile;
  final bool isLoading;
  final int? requestedTabIndex;

  const _HomeScreenStructure({
    required this.tabs,
    this.currentFile,
    required this.isLoading,
    this.requestedTabIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HomeScreenStructure &&
          listEquals(tabs, other.tabs) &&
          currentFile == other.currentFile &&
          isLoading == other.isLoading &&
          requestedTabIndex == other.requestedTabIndex;

  @override
  int get hashCode => Object.hash(
      Object.hashAll(tabs), currentFile, isLoading, requestedTabIndex);
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
