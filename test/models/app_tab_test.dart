import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/app_tab.dart';

void main() {
  group('visibleTabsFor', () {
    test('a web page shows every tab, grouped Page · Code · Network · Trust',
        () {
      final tabs = visibleTabsFor(
          browser: true,
          metadata: true,
          isHtml: true,
          isHtmlOrXml: true,
          server: true);
      expect(tabs.map((t) => t.label), [
        'Browser', 'Metadata', 'Media', 'Services', 'Reader', //
        'DOM Tree', 'Source', //
        'Size', 'Headers', 'Timeline', 'Probe', //
        'Privacy', 'Sovereignty', 'Security', 'Cookies',
      ]);
      // Groups are contiguous, so each group's chips are one run of pages.
      final groups = tabs.map((t) => t.group).toList();
      for (var i = 1; i < groups.length; i++) {
        expect(groups[i].index, greaterThanOrEqualTo(groups[i - 1].index));
      }
    });

    test('a local JSON file only has Source', () {
      final tabs = visibleTabsFor(
          browser: false,
          metadata: false,
          isHtml: false,
          isHtmlOrXml: false,
          server: false);
      expect(tabs, [AppTab.source]);
    });

    test('an XML file has DOM Tree and Source, no page tabs', () {
      final tabs = visibleTabsFor(
          browser: true,
          metadata: false,
          isHtml: false,
          isHtmlOrXml: true,
          server: false);
      expect(tabs, [AppTab.browser, AppTab.domTree, AppTab.source]);
    });
  });
}
