import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/block_page_banner.dart';

import '../fixtures/inspection/browser_blocked.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  testWidgets('a block page gets the banner', (tester) async {
    final service = makeService(seedStore(InspectionStore(), browserBlocked()));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const BlockPageBanner());
    expect(
        find.text('The browser got a block page (HTTP 403), not the site. '
            'What this tab shows describes that page.'),
        findsOneWidget);
  });

  testWidgets('the site itself gets none', (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const BlockPageBanner());
    expect(find.byKey(const ValueKey('block-page-banner')), findsNothing);
  });
}
