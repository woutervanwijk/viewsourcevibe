import 'package:material_ui/material_ui.dart';

/// The four sections of the tab bar.
enum TabGroup {
  page('Page'),
  code('Code'),
  network('Network'),
  trust('Trust');

  final String label;
  const TabGroup(this.label);
}

/// Every tab of the home screen, in display order. The order here is the
/// order on screen and in the TabBarView; [visibleTabsFor] only drops tabs.
enum AppTab {
  browser(TabGroup.page, 'Browser', Icons.language, 'browser'),
  metadata(TabGroup.page, 'Metadata', Icons.info_outline, 'metadata'),
  media(TabGroup.page, 'Media', Icons.perm_media_outlined, 'media'),
  services(TabGroup.page, 'Services', Icons.layers_outlined, 'services'),
  reader(TabGroup.page, 'Reader', Icons.chrome_reader_mode, 'reader'),
  domTree(TabGroup.code, 'DOM Tree', Icons.account_tree_outlined, 'dom-tree'),
  source(TabGroup.code, 'Source', Icons.code, 'source'),
  size(TabGroup.network, 'Size', Icons.scale_outlined, 'page-size'),
  headers(TabGroup.network, 'Headers', Icons.list_alt, 'headers'),
  timeline(TabGroup.network, 'Timeline', Icons.timeline, 'request-timeline'),
  probe(TabGroup.network, 'Probe', Icons.network_check, 'probe'),
  privacy(TabGroup.trust, 'Privacy', Icons.privacy_tip_outlined, 'privacy'),
  sovereignty(TabGroup.trust, 'Sovereignty', Icons.public, 'sovereignty'),
  security(TabGroup.trust, 'Security', Icons.security, 'security'),
  cookies(TabGroup.trust, 'Cookies', Icons.cookie_outlined, 'cookies');

  final TabGroup group;
  final String label;
  final IconData icon;

  /// Tag of the tab's page (focus node and [TabPageWrapper] tag).
  final String tag;

  const AppTab(this.group, this.label, this.icon, this.tag);
}

/// The tabs shown for the loaded content, in display order.
List<AppTab> visibleTabsFor({
  required bool browser,
  required bool metadata,
  required bool isHtml,
  required bool isHtmlOrXml,
  required bool server,
}) =>
    [
      for (final tab in AppTab.values)
        if (switch (tab) {
          AppTab.browser => browser,
          AppTab.metadata ||
          AppTab.media ||
          AppTab.services ||
          AppTab.size ||
          AppTab.privacy =>
            metadata,
          AppTab.reader => isHtml,
          AppTab.domTree => isHtmlOrXml,
          AppTab.source => true,
          AppTab.headers ||
          AppTab.timeline ||
          AppTab.probe ||
          AppTab.sovereignty ||
          AppTab.security ||
          AppTab.cookies =>
            server,
        })
          tab,
    ];
