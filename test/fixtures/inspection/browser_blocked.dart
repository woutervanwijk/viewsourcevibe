import 'package:view_source_vibe/models/inspection/page_inspection.dart';

import 'builders.dart';

const browserBlockedUrl = 'https://www.bol.com/';

/// The rendered DOM the macOS WKWebView got from www.bol.com on
/// 2026-11-13 (validation run 20261113-093209), trimmed: styles, the logo
/// and illustration SVGs, the inline icon and the translated variants of the
/// message removed; contact addresses left out. Playwright WebKit from the
/// same IP got the real shop.
const bolBlockPageDom = '''<!DOCTYPE html>
<html><head>
  <title>bol</title>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="Cache-Control" content="no-cache">
  <meta http-equiv="Content-Language" content="nl">
  <meta name="viewport" content="width=device-width, initial-scale=1 user-scalable=no">
  <script>const language = document.cookie.split("; ").find((row) => row.startsWith("language="))?.split("=")[1];</script>
 </head>
 <body>
  <div class="topbar"><div class="logo-box"><svg class="logo" viewBox="0 0 1134 445"><use xlink:href="#logo" x="0" y="0"></use></svg></div></div>
  <div class="main"><div class="info-box">
   <div id="message">
    <h1 class="bol_header">IP address is blocked</h1>
    <p>
    Your access to bol has been temporarily blocked due to possible abuse from this IP address.<br>
    </p><div class="list-box">
    This may be caused by several factors, including:
    <ul>
     <li><b>Use of a VPN:</b> Please turn off your VPN and try accessing the site again.</li>
     <li><b>Outdated browser or browser extensions:</b> Make sure you're using the latest version of a browser.</li>
     <li><b>Automated scripts:</b> If you're using a script that collects data automatically from bol.com, please refer to our Developer Guide for more information.</li>
    </ul></div><br>
    Please always mention your <a target="_blank" href="https://whatismyip.akamai.com">IP address</a> so we can assist you more effectively.<br><p></p>
   </div>
   <hr>
   If you're a developer and are interested in interfacing with bol, check out our developer guides on <a target="_oai" href="https://developers.bol.com/">developers.bol.com</a> for information about our Open API program.
  </div></div>
</body></html>''';

/// Both the app's own request and the browser got bol.com's Akamai block
/// page (HTTP 403).
PageInspection browserBlocked({int? browserStatus = 403}) {
  final h = hop(browserBlockedUrl, 403, headers: {
    'content-type': ['text/html'],
    'server': ['AkamaiGHost'],
  });
  return urlInspection(
    url: browserBlockedUrl,
    serverResult: server(serverSnapshot(
        url: browserBlockedUrl, hops: [h], body: bolBlockPageDom)),
    browserResult: browser(browserSnapshot(
        url: browserBlockedUrl,
        dom: bolBlockPageDom,
        mainStatus: browserStatus)),
  );
}
