import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/page_size_view.dart';

import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/pump.dart';

void main() {
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
    // 31 KB estimated + 7 KB measured (+ the server document). The decoded
    // part stays a lower bound (own.js has no decoded size): "≥ ≈".
    // Total: decoded is a lower bound (scripts have none), only the
    // transfer carries the estimate.
    expect(find.text('≥ 1 KB (↓ ≈ 38 KB)'), findsOneWidget);
    // Buckets: scripts include the estimate, images are measured.
    expect(find.text('↓ ≈ 33 KB'), findsOneWidget);
    expect(find.text('↓ 5 KB'), findsOneWidget);
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

    expect(find.text('≥ 1 KB (↓ ≥ 7 KB)'), findsOneWidget);
    expect(find.text('↓ ≥ 2 KB'), findsOneWidget);
    expect(find.textContaining('1 resource without size'), findsOneWidget);
    expect(find.textContaining('size lookup failed'), findsWidgets);
    expect(find.textContaining('0 KB'), findsNothing);
  });
}
