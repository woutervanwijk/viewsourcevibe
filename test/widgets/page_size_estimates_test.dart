import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/page_size_view.dart';

import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  setUp(() {
    // Tall viewport: the lazy ListView must build all rows even with the
    // lazy-content note card on top.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(900, 6000);
    view.devicePixelRatio = 1.0;
  });
  testWidgets('iOS partial with estimates: ≈ rows, ≈ total, never 0 KB',
      (tester) async {
    final store = seedStore(InspectionStore(), iosPartial());
    store.applyEstimates(store.current.generation, {
      'https://cdn.other.net/lib.js': const Present(31 * 1024,
          source: DataSource.server, provenance: Provenance.estimated),
    });
    final HtmlService service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PageSizeView());
    await tester.pump();

    expect(find.text('≈ 31 KB'), findsOneWidget);
    // 31 KB estimated + 7 KB measured (+ the server document): the
    // download total carries the estimate.
    expect(find.text('≈ 38 KB'), findsOneWidget);
    // Buckets: scripts include the estimate, images are measured (bucket
    // and the image's own row).
    expect(find.text('≈ 33 KB'), findsOneWidget);
    expect(find.text('5 KB'), findsNWidgets(2));
    expect(find.textContaining('includes estimates'), findsOneWidget);
    expect(find.textContaining('≥ ≈'), findsNothing);
    expect(find.textContaining('estimate'), findsWidgets);
    expect(find.textContaining('without size'), findsNothing);
    expect(find.textContaining('0 KB'), findsNothing);
    expect(find.textContaining('0 B'), findsNothing);
  });

  testWidgets('a failed lookup keeps the lower bound and the missing note',
      (tester) async {
    final store = seedStore(InspectionStore(), iosPartial());
    store.applyEstimates(store.current.generation,
        {'https://cdn.other.net/lib.js': const Failed('timeout')});
    final service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PageSizeView());
    await tester.pump();

    expect(find.text('≥ 7 KB'), findsOneWidget);
    expect(find.text('≥ 2 KB'), findsOneWidget);
    expect(find.textContaining('1 resource without size'), findsOneWidget);
    expect(find.textContaining('size lookup failed'), findsWidgets);
    expect(find.textContaining('0 KB'), findsNothing);
  });
}
