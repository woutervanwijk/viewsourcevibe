import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class WebViewExtractor extends StatefulWidget {
  const WebViewExtractor({super.key});

  @override
  State<WebViewExtractor> createState() => _WebViewExtractorState();
}

class _WebViewExtractorState extends State<WebViewExtractor> {
  WebViewController? _controller;
  String? _currentlyLoadingUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (_currentlyLoadingUrl == url) {
              await _extractContent(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      );
  }

  Future<void> _extractContent(String url) async {
    if (_controller == null) return;
    try {
      final html = await _controller!.runJavaScriptReturningResult(
          'document.documentElement.outerHTML') as String;

      // The result might be a quoted string depending on the platform implementation
      String finalHtml = html;
      if (finalHtml.startsWith('"') && finalHtml.endsWith('"')) {
        try {
          // Use jsonDecode for robust unescaping (handles \uXXXX, \n, etc.)
          finalHtml = jsonDecode(finalHtml) as String;
        } catch (e) {
          debugPrint('Error unquoting HTML via jsonDecode: $e');
          // Naive fallback
          finalHtml = finalHtml
              .substring(1, finalHtml.length - 1)
              .replaceAll('\\"', '"')
              .replaceAll('\\\\', '\\')
              .replaceAll('\\n', '\n')
              .replaceAll('\\r', '\r')
              .replaceAll('\\t', '\t');
        }
      }
      if (!mounted) return;
      final htmlService = Provider.of<HtmlService>(context, listen: false);
      await htmlService.completeWebViewLoad(finalHtml, url);
      setState(() {
        _currentlyLoadingUrl = null;
      });
    } catch (e) {
      debugPrint('Error extracting HTML: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        if (htmlService.isWebViewLoading &&
            htmlService.webViewLoadingUrl != null) {
          if (_currentlyLoadingUrl != htmlService.webViewLoadingUrl) {
            _currentlyLoadingUrl = htmlService.webViewLoadingUrl;
            _controller?.loadRequest(Uri.parse(_currentlyLoadingUrl!));
          }

          return Container(
            height: 1, // Minimize visibility but keep in tree
            width: 1,
            color: Colors.transparent,
            child: WebViewWidget(controller: _controller!),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
