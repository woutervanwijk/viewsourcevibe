import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/metadata_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Structured Data Viewer', () {
    late HtmlService htmlService;

    setUp(() {
      htmlService = HtmlService();
    });

    // loadFile extracts metadata in an isolate, which only runs on the real
    // event loop, so load outside the fake-async test zone and wait for it.
    Future<void> load(WidgetTester tester, HtmlFile file) =>
        tester.runAsync(() async {
          await htmlService.loadFile(file);
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while ((htmlService.isExtractingMetadata ||
                  htmlService.pageMetadata == null) &&
              DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(milliseconds: 20));
          }
        });

    testWidgets('recognizes @graph JSON-LD nodes, never "Unknown schema"',
        (WidgetTester tester) async {
      // As served by www.groningen.nl: entities in @graph, author/publisher
      // as @id references; plus an untyped schema.org node in a second block.
      final testFile = HtmlFile(
        name: 'groningen.html',
        path: 'https://www.groningen.nl/',
        content: '''
<html><head><title>Groningen.nl</title>
<script type="application/ld+json">
      {"@context":"https://schema.org","@graph":[{"@type":"WebSite","author":{"@id":"#identity"},"dateModified":"2026-10-26T13:06:26+01:00","datePublished":"2023-08-14T13:17:00+02:00","name":"Groningen.nl","publisher":{"@id":"#creator"},"url":"https://www.groningen.nl/"},{"@id":"#identity","@type":"LocalBusiness","priceRange":"\$","sameAs":["https://www.instagram.com/internationalgroningen/"]},{"@id":"#creator","@type":"Organization","name":"Gemeente Groningen"},{"@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","item":"https://www.groningen.nl/","name":"Home","position":1}],"name":"Breadcrumbs"}]}
    </script>
<script type="application/ld+json">{"@context":"https://schema.org","@id":"#node"}</script>
</head><body></body></html>
''',
        lastModified: DateTime.now(),
        size: 100,
        isUrl: true,
      );

      await load(tester, testFile);
      expect(htmlService.pageMetadata, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<HtmlService>.value(value: htmlService),
              ChangeNotifierProvider(create: (_) => AppSettings()),
            ],
            child: const Scaffold(body: MetadataView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each @graph node is listed with its recognized @type…
      expect(find.text('WebSite'), findsWidgets);
      expect(find.text('LocalBusiness'), findsWidgets);
      expect(find.text('Organization'), findsWidgets);
      expect(find.text('BreadcrumbList'), findsWidgets);
      // …the untyped node is recognized by its schema.org vocabulary…
      expect(find.text('schema.org'), findsWidgets);
      // …and nothing is reported as an unknown schema.
      expect(find.text('Unknown schema'), findsNothing);
    });
  });
}
