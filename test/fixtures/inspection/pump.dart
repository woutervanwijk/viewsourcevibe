import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/collectors/browser_loader.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/derive/dom_tree.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

/// A fetcher that never answers: widget tests seed the store directly.
class SilentServerFetcher implements ServerFetcher {
  @override
  Future<ServerSnapshot> fetch(Uri url,
          {required String userAgent, int maxBytes = 10 << 20}) =>
      Completer<ServerSnapshot>().future;

  @override
  Future<RobotsInfo> fetchRobots(Uri origin, {required String userAgent}) =>
      Completer<RobotsInfo>().future;
}

class SilentBrowserLoader implements BrowserLoader {
  @override
  void loadUrl(Uri url) {}
}

/// Pushes [p] into [store] through the store's public API (a new generation).
/// Pending cores stay pending. Returns [store].
InspectionStore seedStore(InspectionStore store, PageInspection p) {
  final t = p.target;
  switch (t) {
    case UrlTarget():
      final gen = store.beginUrl(t.url);
      if (p.server is! Pending<ServerSnapshot>) {
        store.applyServer(gen, p.server);
      }
      final b = p.browser;
      if (b is Present<BrowserSnapshot>) {
        store.applyBrowser(gen, b.value);
        // A fixture is a finished load.
        store.markBrowserSettled(gen);
      } else if (b is! Pending<BrowserSnapshot>) {
        store.applyBrowserFailure(gen, b);
      }
      if (p.robots is! Pending<RobotsInfo>) store.applyRobots(gen, p.robots);
      if (p.freshLoad is! Unavailable<BrowserSnapshot>) {
        store.applyFreshLoad(gen, p.freshLoad);
      }
    case FileTarget():
      store.beginFile(t.file);
    case NoTarget():
      store.clear();
  }
  store.setPrimaryDocument(p.primaryDocumentPreference);
  return store;
}

/// An HtmlService on its own store that never touches the network.
HtmlService makeService([
  InspectionStore? store,
  DomTreeBuilder? domTreeBuilder,
  int? domTreeIsolateThreshold,
]) =>
    HtmlService(
      domTreeBuilder: domTreeBuilder,
      domTreeIsolateThreshold: domTreeIsolateThreshold ?? 256 * 1024,
      store: store ?? InspectionStore(),
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
    );

/// Like [makeService], but with the real metadata parser (no isolate).
HtmlService makeServiceWithMetadata(InspectionStore store) => HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async =>
          extractMetadataSync(html, baseUrl, headers: headers),
    );

HtmlFile htmlFileFor(PageInspection p, {String content = ''}) {
  final t = p.target;
  if (t is UrlTarget) {
    return HtmlFile(
        name: 'index.html',
        path: t.url.toString(),
        content: content,
        lastModified: DateTime(2024),
        size: content.length,
        isUrl: true);
  }
  final f = (t as FileTarget).file;
  return HtmlFile(
      name: f.name,
      path: f.path,
      content: f.text.text,
      lastModified: DateTime(2024),
      size: f.byteLength);
}

/// Pumps [child] with the providers the tabs need.
Future<void> pumpWithProviders(
  WidgetTester tester, {
  required HtmlService service,
  required Widget child,
  AppSettings? settings,
}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<HtmlService>.value(value: service),
      ChangeNotifierProvider<AppSettings>.value(
          value: settings ?? AppSettings()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  ));
}
