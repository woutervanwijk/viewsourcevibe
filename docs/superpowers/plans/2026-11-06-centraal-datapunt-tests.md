# Centraal datapunt + datacorrectheid via tests — Implementatieplan

> **Voor agentic workers:** VERPLICHTE SUB-SKILL: gebruik superpowers:subagent-driven-development (aanbevolen) of superpowers:executing-plans om dit plan taak voor taak uit te voeren. Stappen gebruiken checkboxes (`- [ ]`).
> Na akkoord eerst dit plan opslaan als `docs/superpowers/plans/2026-11-06-centraal-datapunt-tests.md`.

## Context

De app toont data uit drie bronnen: de **browser** (WebView), **curl** (directe HTTP via dart:io) en **file://** (lokale/gedeelde bestanden). Die data zit nu grotendeels in `HtmlService` (`lib/services/html_service.dart`, 5160 regels), maar:
- staat in ongetypeerde `Map<String, dynamic>`-maps, waarin de drie bronnen door elkaar lopen (bijvoorbeeld `_currentFile.content` is soms server-HTML en soms gerenderde DOM);
- toont "onbekend" als echte waarde (`0 B`, `N/A`, `null null`, "none found");
- heeft race-conditions, waardoor data van pagina A op pagina B belandt;
- wordt deels in widgets zelf geparsed of opgehaald.

Doel: één centraal, reactief datapunt met drie gescheiden kernen. Elk getoond gegeven heeft een bron, en "niet zichtbaar" wordt expliciet gemeld met een reden. Tests leggen de data in dat punt vast, plus de UI die eruit wordt gegenereerd. **Regel: correctheid boven alles; wat we niet kunnen zien, melden we.**

Keuzes van de gebruiker:
1. De Source-tab toont standaard de **gerenderde DOM**; daarnaast is de **server-HTML** in te schakelen. Die server-HTML moet daarvoor wel echt worden opgehaald (zie B1).
2. **Getypeerde snapshot-klassen + `Observed<T>`**, stapsgewijs ingevoerd met tijdelijke map-adapters.
3. **Dode code verwijderen** in de eerste fase.

**Doel:** alle getoonde data komt uit `InspectionStore` (drie kernen plus afgeleide data), en elke waarde is aantoonbaar correct of expliciet "niet beschikbaar".
**Architectuur:** collectors (server/browser/file) leveren immutable snapshots aan een `InspectionStore` (ChangeNotifier). Resultaten van een oude navigatie worden geweigerd via een generatie-token. Afgeleide data (metadata, detecties, cookies, gewicht, soevereiniteit) wordt berekend door pure functies op die snapshots. Widgets lezen via `Selector`.
**Tech stack:** Flutter/Dart 3 (sealed classes), provider, flutter_inappwebview, dart:io HttpClient, package:html/xml, flutter_test.

## Global Constraints

- Flutter SDK `>=3.3.0 <4.0.0`; state via `provider`; mutaties alleen in ChangeNotifiers in `services/`/`models/` (AGENTS.md).
- Geen `print()`; fouten worden zichtbaar in de UI, niet alleen via `debugPrint`.
- Elke getoonde waarde is een `Observed<T>` met `DataSource` (`browser`/`server`/`file`) en `Provenance` (`measured`/`derived`/`estimated`).
- Onbekend wordt nooit `0`, `'N/A'`, `''` of een placeholder-map: dan is het `Unavailable(reason)` of `Pending`.
- Tests draaien volledig offline: lokale `HttpServer`, byte-fixtures en opgenomen browser-payloads. `HttpOverrides.global` wordt na elke test hersteld.
- WebView-instellingen en geïnjecteerde scripts alleen wijzigen met een handmatige check per platform (AGENTS.md §4).
- Source-tab: standaard rendered DOM, server-HTML schakelbaar; elke analysetab laat zien welk document hij gebruikt.

## Review Focus

1. **Snel navigeren A→B terwijl A nog laadt.** Geen enkel veld van A mag op B verschijnen (metadata, probe, resources, cookies, sizes, robots). Test hoort bij Taak 7.
2. **Site met botbescherming** (curl krijgt 403 of een challenge, de browser 200). Beide statussen tonen, elk met hun bron, en het verschil markeren. De challenge-pagina mag niet als "de site" worden gepresenteerd. Test hoort bij Taak 4 en Taak 9.
3. **iOS, cross-origin zonder Timing-Allow-Origin** (zoals rtvutrecht.nl, ff1fa47). Groottes zijn dan `Unavailable(blockedByPlatform)` of `estimated` via een losse request, met label. Nooit 0, nooit decoded pixelbuffer. Test hoort bij Taak 5 en Taak 9.
4. **Niet-UTF-8 pagina of bestand** (Latin-1, windows-1252, UTF-16 met BOM). Correct gedecodeerd, charset en bron zichtbaar; een niet-ondersteunde charset wordt gemeld. Test hoort bij Taak 3.
5. **Lokaal bestand openen na een URL.** Size, Timeline, Services en Privacy tonen niets van de vorige site, en server-velden zijn `Unavailable(notApplicable)`. Test hoort bij Taak 7.

---

## Deel A — Index: alle data die nu wordt verzameld, en hoe

### A1. Server-kern (curl / dart:io)

| Veld | Nu opgeslagen | Hoe verzameld | Getoond in |
|---|---|---|---|
| status, reason | `probeResult.statusCode/reasonPhrase` | R1: HEAD, fallback `GET Range: bytes=0-0` (`html_service.dart:2706`), UA `curl/7.88.1`; of de laatste hop van R4 | Probe General, Timeline, Export |
| headers | `probeResult.headers` | lowercase, herhaalde headers samengevoegd met `", "`, set-cookie eruit (`:2766`, `:2387`) | Headers, Security, Detections |
| redirect-keten, finalUrl, isRedirect | `redirectChain/redirectLocation/finalUrl` | R1 = 1 hop (`:2835`); R3 `_getFinalUrlAfterRedirects` (`:1287`), een GET per hop; R4 eind-GET | Probe, Timeline |
| IP | `ip`/`ipAddress` | aparte `InternetAddress.lookup` van de *oorspronkelijke* host (`:2304`, `:2689`) | Probe Network |
| responstijd | `timing.total`/`responseTime` | stopwatch, inclusief DNS en certificaatdialoog | Probe Network |
| contentLength | `contentLength` | header, of -1 bij decompressie of chunked transfer (`:2410`) | Probe |
| security-headers | `security` (6 headers) | kopie uit de headers (`:2778`, `:2401`) | Security-scorecard |
| Set-Cookie | `cookies` (raw strings) | headers, alleen van de laatste hop | Cookies |
| certificaat | `certificate` (alleen leaf) | `probe_service.dart:152 extractCertificateInfo` | Security, Jurisdictie |
| TLS-waarschuwing | `tlsInvalidCertificate/tlsWarning` | `certificate_security_service.dart` | Source, Security |
| robots/sitemap | `robotsSitemap` | R2: GET `/robots.txt`, HEAD `/sitemap.xml`, UA `ViewSourceVibe/1.0` (`:2908-3023`) | Probe |
| server-HTML | `_lastServerSource` | R4-body, `utf8.decode(allowMalformed)` (`:2381`) | Source Diff (alleen na knop) |
| resource-groottes | `item['size']`, timeline `transfer/decoded` | R5 `_fetchResourceSize` (`:4987`): ranged GET, daarna HEAD, met Android Chrome-UA | Size, Media |
| soevereiniteit | `sovereigntyReport` | R6: DNS per host, RIPEstat ×3 per host (maximaal 40 hosts), DoH (libredns, dns.google), `/.well-known/security.txt` (`sovereignty_service.dart:1165-1305`) | Sovereignty |
| logo's | `LogoService`-cache | R7 DuckDuckGo-favicon (`logo_service.dart:41`), aangeroepen vanuit de widget | overal |

### A2. Browser-kern (WebView)

Verzameld via `syncWebViewState` (`html_service.dart:4273`). Dat draait bij progress ≥98 (partial; op iOS meestal overgeslagen) en bij `onLoadStop`. Daarna volgen gewicht-refreshes op +4 s en +14 s.

| Veld | Nu opgeslagen | Hoe verzameld | Getoond in |
|---|---|---|---|
| rendered DOM | `_currentFile.content` (`:4674`) | DOCTYPE + `outerHTML`, of `XMLSerializer`, plus `<pre>`-unwrap (`:4352`) | Source, DOM Tree, Metadata, Media, Services |
| documentgrootte | `_currentFile.size` (`:4676`) | navigation `decodedBodySize`, anders `content.length` | Source ("bytes") |
| resources `{name,transfer,decoded,startTime,duration}` | `_resourcePerformanceData` | `window.__vsv_res` (gebufferde PerformanceObserver + fetch/XHR-patches, `browser_view.dart:195-276`) en `getEntriesByType('resource')` | Size, Timeline, Sovereignty, Detections, Export |
| omgeving, pageWeight, resourceCount, storage | `_browserProbeResult` (`:4593-4640`) | dezelfde JS; storage via een lus over local/sessionStorage | Probe Browser-card, Storage, Timeline |
| `serverStatusCode`, `title` | `_browserProbeResult` (`:4603`) | **kopie** van de curl-status en de metadata op het moment van sync | Browser-card als "HTTP Status" |
| cookies | `_lastBrowserCookies` (`:4505`) | `CookieManager.getCookies`, daarna origin-fallback, daarna `document.cookie`; alleen `name=value` (`:4482`) | Cookies, Detections |
| pagina-gewicht | `_lastPageWeight` → `pageMetadata['pageWeight']` | afgeleid van resources; fallback naar server (`:2470`) | Size |
| URL, laadvoortgang | `_currentInputText`, `_webViewLoadingProgress` | WebView-callbacks | URL-balk |

### A3. File-kern (file://, picker, delen, deep links)

`HtmlFile` (`lib/models/html_file.dart`) bevat alleen `name, path, content (String), size, lastModified, isUrl, isError, isShared, probeResult`. Bytes, encoding en mime-type worden niet bewaard.

| Ingang | Waar | Lezen | size | lastModified |
|---|---|---|---|---|
| file picker | `toolbar.dart:51-71` | bytes + `utf8.decode(allowMalformed)` | bytes | `now()` |
| deep link `file?path=` | `main.dart:110-130` | `readAsString` (gooit een fout bij niet-UTF-8) | `length()` | echt |
| deep link `text?content=` | `main.dart:81-88` | query-param | UTF-16-lengte | `now()` |
| deep link `content://` | `main.dart:230-237` | uitlegtekst, `isError` niet gezet | tekstlengte | `now()` |
| restore/reload | `main.dart:443`, `html_service.dart:905` | `readAsString` | `length()` | echt |
| delen: tekst | `unified_sharing_service.dart:425` | as-is | `text.length` | `now()` |
| delen: bytes | `unified_sharing_service.dart:505` | `String.fromCharCodes` (Latin-1) | bytes | `now()` |
| delen: pad | `unified_sharing_service.dart:799` | `readAsString`, **geen sandbox-check** | `length()` | echt |

### A4. Afgeleide data (nu op allerlei plekken)

- `selectedContentType`, `isHtml/isXml/isSvg/isMedia` (`html_service.dart:310-593`): worden bij elke aanroep opnieuw berekend uit probe-header, selectie, extensie, sniff en invoertekst.
- `pageMetadata`: `metadata_parser.dart` draait in een isolate op `_currentFile.content`. Welk document dat is (DOM of server) hangt af van wat het laatst geladen werd.
- `detections` (`html_service.dart:210`): `detect()` uit `detection/engine.dart` op source, requests en cookies.
- `analyzedCookies`: `CookieUtils.mergeCookies` (`cookie_utils.dart`) voegt samen **op naam alleen**.
- `siteJurisdiction` (`jurisdiction.dart:223`): certificaatland, anders schema.org, anders ccTLD.
- `sovereigntyReport`.

Wat **geen data** is en dus in de UI-state blijft: tab-index, scroll-controllers, find, beautify en invoertekst.

---

## Deel B — Gevonden fouten, risico's en optimalisaties

Regelnummers verwijzen naar `lib/services/html_service.dart`, tenzij er een ander bestand staat. Ze zijn bij de scan nagecontroleerd.

### Kritiek: getoonde data is fout of misleidend

| # | Probleem | Waar |
|---|---|---|
| B1 | **In browser-first-modus (de standaard) wordt de server-HTML nooit opgehaald.** `_resetLoadState` zet `_isLoading = true`, waarna `_loadSourceOnly` meteen terugkeert via `if (_isLoading) return;`. Gevolg: Source, Metadata en Services draaien op de DOM, `serverSource` blijft null, de probe is alleen een HEAD en de redirect-keten heeft hooguit 1 hop. Dit werkt al sinds commit 29b8918 niet. | `:742`, `:640`, `:868` |
| B2 | **Source-first: `_lastServerSource` wordt meteen gewist** door `loadFile`→`clearFile`; `robotsSitemap` verdwijnt daarbij ook. Wie daarna de Browser-tab opent, ziet de server-HTML vervangen door de DOM. | `:2382`→`:1878`→`:2144` |
| B3 | **Nep-probe** `_probeResult ??= {'finalUrl': …}`. Daardoor wordt niet opnieuw geprobed, wordt `probeError` verborgen, toont de statuschip een groene "null null", meldt Sovereignty HSTS als FAIL in plaats van onbekend, en wordt de nep-probe ook nog bewaard. Twee tests leggen dit gedrag vast (`simple_tab_test`, `tab_update_test`). | `:3845` |
| B4 | **Race in metadata.** `_extractMetadata` laat een nieuw verzoek vallen als er al een loopt en schrijft het resultaat zonder URL-check. `_isExtractingMetadata` wordt niet gereset, dus metadata van pagina A komt op B terecht. | `:3801`, `:3814` |
| B5 | **Race in browser-sync en sizes.** `syncWebViewState` controleert de URL niet opnieuw na een `await`. Ook `_lastServerSource`, `_fetchMissingMetadataSizesAsync` en `_enrichResourceSizes` schrijven na navigatie gewoon door. | `:4308-4681`, `:4219`, `:4862` |
| B6 | **Probe blijft hangen.** `syncWebViewState` zet `_currentlyProbingUrl` vóór `probeUrl`, zodat de guard terugkeert. Daarna blijft `_isProbing` voor altijd `true`. | `:4293`, `:2627`, `:2900` |
| B7 | **`clearFile` is onvolledig**: browser-probe, gewicht, resources, soevereiniteit en browsercookies blijven staan. Een lokaal bestand na een URL toont dus de vorige site in Size, Timeline, Services en Privacy. | `:2122-2153` |
| B8 | **`<pre>`-unwrap kaapt echte pagina's.** Elke pagina zonder DOCTYPE met een `<pre>` wordt in Source vervangen door het eerste `<pre>`-blok. | `:4352-4372` |
| B9 | **Groottes zijn tekens, geen bytes.** `content.length` wordt als "bytes" gebruikt (`:2481`, `:2472`, `:4676`, `:2978`, `source_viewer.dart:320`). Verder: `transfer` = **-1** zonder Content-Length (`:2410`/`:2471`), een verzonnen 0 (`:2761`), DOM-lengte als gewicht (`:4454-4460`), en data-URI- en storage-lengte als bytes. De echte `bytes.length` (`:2380`) wordt weggegooid. | diverse |
| B10 | **iOS: decoded pixelbuffer van afbeeldingen telt nog mee** in totalen en breakdown. ff1fa47 repareerde alleen `ResourceSize.size`. | `:4569`, `:4911`, `page_size_view.dart:201,260`, `media_view.dart:133,482` |
| B11 | **Cache-hit wordt overschreven.** Bij `transfer==0` maar een echte `decoded` haalt R5 opnieuw op en zet beide velden op de gecomprimeerde lengte. R5 maakt `transfer` ook altijd gelijk aan `decoded`. | `:4829`, `:4850`, `:4238` |
| B12 | **Refresh gooit `startTime`/`duration` weg**, waardoor de Timeline die resources op 0 tekent. | `:4786` |
| B13 | **fetch/XHR-patches tellen dubbel.** Een relatieve URL levert een tweede sleutel op naast de absolute; content-length (gecomprimeerd) wordt opgeslagen als `decoded`. | `browser_view.dart:246-251` |
| B14 | **Charset wordt genegeerd.** Server: `utf8.decode(allowMalformed)` (`:2381`, `:3015`). File: `readAsString` gooit een fout bij Latin-1. Gedeelde bytes: `String.fromCharCodes` (`unified_sharing_service.dart:505`). | diverse |
| B15 | **IP is niet het IP van de server die antwoordde.** Het komt uit een aparte lookup van de oorspronkelijke host, en Sovereignty doet nog een eigen lookup. Beschikbaar maar ongebruikt: `connectionInfo.remoteAddress`. | `:2304`, `:2689` |
| B16 | **De redirect-follower slikt fouten** en geeft de oorspronkelijke URL terug als "final" (`:1362-1375`). R4 volgt daarna zelf nog eens redirects, dus de content kan van een andere URL komen dan `finalUrl`. Ook: een extra GET per hop en een ongebruikte `client`-parameter. | `:1287-1379`, `:2342` |
| B17 | **`areUrlsEqual` negeert scheme en poort** en ziet `''` en `'/'` als verschillend. Bij http→https geldt de URL daardoor als "al geprobed", en worden de 301-headers als die van de site getoond. | `:1794` |
| B18 | **`isRedirect = finalUrl != url`** geeft vals-positieven door Uri-normalisatie. | `:2419` |
| B19 | **`serverStatusCode` in de browser-card is de curl-HEAD-status**, maar heeft het label "HTTP Status". `title` is een verouderde kopie. | `:4603-4604`, `probe_views.dart:943` |
| B20 | **Cookies.** Browsercookies worden alleen als `name=value` bewaard (flags weg), samenvoegen gebeurt op naam alleen, third-party-cookies worden nooit verzameld, en Max-Age/Path worden genegeerd. | `:4482`, `cookie_utils.dart:4419-4441` |
| B21 | **SPA-navigatie wordt niet gevolgd.** URL, DOM en metadata blijven op de eerste route staan, terwijl resources van alle routes wel worden opgeteld. | `browser_view.dart:238-241` (geen `onUpdateVisitedHistory`) |
| B22 | **Eén try-blok voor storage, gewicht en cookies.** Een `SecurityError` op localStorage gooit alles weg. | `:4390-4656` |

### Hoog/middel

- **B23** `as Map<String,String>?` na een restore gooit een fout, die stil wordt opgevangen, waarna het type wordt gereset (`:1956`).
- **B24** Gedeelde tekst die ergens een URL bevat, wordt vervangen door het laden van die URL (`unified_sharing_service.dart:262-266`). De heuristiek `contains('.') && length>10` laat content verloren gaan (`:1073`).
- **B25** De DOCTYPE-check in de DOM Tree is hoofdlettergevoelig. `<!doctype html>` gaat daardoor naar de XML-parser en geeft "corrupt-xml" (`dom_tree_view.dart:63`).
- **B26** Lokale HTML heeft een lege baseUrl en `<base href>` wordt genegeerd. Een relatieve link opent dan als `https://img/a.png` (`:3805`, `contextmenu.dart:199`).
- **B27** Sovereignty negeert de DNS-rcode, zodat SERVFAIL als FAIL wordt getoond (`sovereignty_service.dart:1322-1371`). `registrableDomain` is naïef (github.io, ne.jp; `:1262`). security.txt telt alleen bij status 200.
- **B28** Het certificaat-subject wordt op komma's gesplitst, dus `O=Example, Inc.` breekt (`probe_service.dart:185`). De jurisdictie neemt eerst het certificaatland, dus het land van een CDN met OV-certificaat.
- **B29** `_isProbing = false` in `_loadFromUrlInternal`, terwijl R1 nog loopt (`:2446`).
- **B30** Dubbele probes vanuit deep link, delen en de Probe-knop (`main.dart:248`, `sharing_service.dart:161`, `probe_views.dart:1056`).
- **B31** Beveiliging: een gedeeld bestandspad wordt zonder `resolveWithinAppDirectories` gelezen (`unified_sharing_service.dart:720-804`). Ook mist de `content://`-foutpagina `isError` (`main.dart:230`).
- **B32** `_shouldAddToHistory` weigert lokale bestanden, waardoor de URL-balk `https://index.html` laadt (`:1712`, `url_input.dart:114-151`). Pull-to-refresh op een lokaal bestand laadt `https://<bestandsnaam>` (`home_screen.dart:136`).
- **B33** `debugPrint('…\$url: \$e')` print de letterlijke tekst in plaats van de waarden (`:5050`).
- **B34** Privacy: cookiewaarden, ook HttpOnly-sessiecookies, worden via `jsonEncode(_probeResult)` op schijf bewaard (`:1175`).
- **B35** `LogoService` bewaart een niet-200-antwoord als null voor de rest van de sessie (`logo_service.dart:41-44`).
- **B36** `ChangeNotifierProvider(create: (_) => bestaandeInstantie)` moet `.value` zijn (`main.dart:333-337`).
- **B37** `metadata_view.dart:498` leest `'canonical'`, maar dat veld wordt nooit gevuld. `html_file.dart:51`: "Shared text" krijgt de extensie `'shared text'`.

### Dode code (Taak 1)

`completeWebViewLoad` (`:946`, verzint status 200, `'OK (via Browser)'` en `ipAddress 'N/A'`), `extractCurrentWebViewContent` (`:5106`), `updateWebViewUrl` (`:5091`), `ProbeService.probeUrl` (`probe_service.dart:8-150`), `SharedContentManager`, `SharingService.handleSharedContent` (inclusief legacy-takken), `PlatformSharingHandler`, `UrlDialog`, plus de tests die alleen deze code dekken.

### Optimalisaties

- **O1** Alle tabs luisteren naar elke notify, ook naar progress-ticks (`:704`). Metadata, Media, Services, Privacy en DOM Tree parsen dan per tick opnieuw. Oplossing: een `Selector` op een immutable view-model.
- **O2** De DOM wordt 2× per sync in de isolate geparsed (`:2027`, `:4697`) en 2-3× gekopieerd; er is geen limiet op de DOM-grootte.
- **O3** Tot 4 rondes size-lookups (GET + HEAD per resource); RIPEstat zonder concurrency-limiet (40×3 calls).
- **O4** Gedupliceerde logica: gewicht-JS 2× (`:4434`/`:4720`), breakdown-lus 2×, size-lookups 2×.
- **O5** Minstens 3 hits op de origin per navigatie (HEAD, GET per redirect-hop, eind-GET). Dat kan één keten worden.
- **O6** `isHtml/isXml/…` worden bij elke aanroep opnieuw berekend; één keer per snapshot is genoeg.
- **O7** Timeouts ontbreken: geen connect-timeout bij R3/R4, en de body-lus heeft geen timeout (`:2573`).
- **O8** Een hard-gecodeerde UA (curl, Android Chrome 114) roept botmuren op. De UA moet expliciet zijn en in de snapshot worden vastgelegd.

---

## Deel C — Wanneer data niet beschikbaar kan zijn (wat we dan melden)

Elk geval wordt `Unavailable(reason, detail)` of krijgt het label `Provenance.estimated`, en heeft een test (de taak staat tussen haakjes).

| Gegeven | Wanneer niet (of fout) beschikbaar | Melding / gedrag |
|---|---|---|
| Resource-transfer/decoded | iOS/macOS: cross-origin zonder `Timing-Allow-Origin` geeft 0/0 (ff1fa47) | `blockedByPlatform`; een losse meting heet `estimated` met "eigen request, kan afwijken (UA/cookies)" (T5, T9) |
| Decoded van afbeeldingen | WebKit rapporteert de pixelbuffer | decoded bij afbeeldingen niet tonen; transfer is leidend (T9) |
| Transfer | Android cache-hit / service worker geeft 0 | `servedFromCache` in plaats van 0; decoded blijft staan (T5) |
| Late resources | geladen na +14 s, lazy-load, SPA-routes | totalen gemarkeerd als "momentopname tot t=…" (T5) |
| DOM | iframes, shadow DOM, SPA-route na pushState | melding "iframes/shadow DOM niet meegenomen"; SPA: nieuwe snapshot bij `onUpdateVisitedHistory` (T5, T8) |
| Browsercookies | HttpOnly onzichtbaar via `document.cookie`; geen flags op Android; geen third-party | flags `Unavailable(notExposedToPage)`; sectie "third-party: niet verzameld" (T5, T9) |
| JS-resultaten | Windows/Linux-WebView (beta): een niet-String-resultaat | `unsupportedPlatform` in plaats van lege lijsten (T5) |
| Fetch/XHR-patch | een pagina vervangt `fetch`/XHR | resources alleen via de PerformanceObserver; de patch-bron wordt gelabeld (T5) |
| Server-respons | botbescherming (403/challenge), geo- of consent-muur, UA-afhankelijke content | status tonen zoals gemeten, met de UA erbij, en de "curl ≠ browser"-divergentie markeren (T4, T9) |
| Status via HEAD | HEAD geeft 405/501 | één GET-keten, dus geen HEAD-status meer (T4) |
| Body | >10 MB | afkappen met de vlag `exceedsLimit` in plaats van een foutpagina (T4) |
| Redirects | >5 hops, een lus, of een niet-http-scheme | keten tot het afbreekpunt + reden; nooit de oorspronkelijke URL als "final" (T4) |
| Cookies over redirects | Set-Cookie op tussen-hops | per hop vastleggen (T4) |
| IP | DNS-fout, IPv4/IPv6 | IP van de verbonden socket; anders `failed` (T4) |
| Charset | niet-UTF-8, onbekende charset | decoderen volgens header/BOM/meta; onbekend geeft een melding plus Latin-1-weergave, `estimated` (T3) |
| Certificaat | alleen het leaf-certificaat; geen SAN, keten of TLS-versie | velden die er niet zijn: `Unavailable(notReportedByPlatform)` (T4) |
| Soevereiniteit | RIPEstat rate-limit, DoH-fout, SERVFAIL; geolocatie is een gok | per host `failed`/`unknown` in plaats van FAIL; land met label `estimated` (T9) |
| Jurisdictie, cookiecategorie, detectie-confidence | heuristisch | altijd `Provenance.derived` met de reden "afgeleid van …" (T9) |
| Lokaal bestand | binair, niet-UTF-8, `content://` zonder pad, onbekende lastModified, relatieve resources | binair: hex/media-weergave of melding; lastModified `Unavailable`; relatieve links "niet op te lossen" (T6) |
| Server-velden bij een lokaal bestand | n.v.t. | `Unavailable(notApplicable)`: de server-tabs worden verborgen, maar tonen nooit oude data (T7) |

---

## Deel D — Doelarchitectuur

```
lib/models/inspection/
  observed.dart          Observed<T> (sealed): Present(value, source, provenance) | Unavailable(reason, detail) | Pending | Failed(error)
                         enum DataSource {browser, server, file}; enum Provenance {measured, derived, estimated}
                         enum UnavailableReason {notApplicable, blockedByPlatform, blockedBySite, notExposedToPage,
                                                 notReportedByServer, notReportedByPlatform, servedFromCache,
                                                 exceedsLimit, unsupportedPlatform}
  server_snapshot.dart   ServerSnapshot: requestedUrl, hops (List<HttpHop>{url,status,reason,headers,setCookies,remoteAddress}),
                         finalUrl, body (DecodedText + byteLength + truncated), timing, certificate, robots, userAgent
  browser_snapshot.dart  BrowserSnapshot: url, renderedDom (DecodedText-achtig, alleen chars), resources (List<ResourceEntry>),
                         cookies (List<BrowserCookie> met Observed-flags), storage, navigationTiming, platform (BrowserPlatform)
  file_snapshot.dart     FileSnapshot: name, uri/path, origin (picker/share/deeplink/restore), bytes, text (DecodedText|binary),
                         byteLength, lastModified (Observed<DateTime>)
  page_inspection.dart   PageInspection: generation, target, server/browser/file: Observed<…Snapshot>;
                         gememoïseerde afgeleiden: contentKind, metadata(docSource), detections, cookies, pageWeight, divergences
lib/services/inspection_store.dart   InspectionStore extends ChangeNotifier (het centrale punt)
lib/services/collectors/  server_fetcher.dart · browser_payload.dart (pure parser) · file_loader.dart
lib/services/derive/      metadata, detections, cookies, page_weight, resource_matching, sovereignty-input
lib/utils/text_decoding.dart         DecodedText decode(List<int> bytes, {String? contentType}) → text, charset, charsetSource, malformed
lib/widgets/observed_value.dart      één widget voor Present / Unavailable("Niet zichtbaar: …") / Pending / Failed
```

Regels:
- Elke navigatie verhoogt `generation`. Elke `apply*` krijgt de generatie mee, en een niet-huidige generatie wordt genegeerd. Zo verdwijnt de hele klasse races B4/B5/B6.
- `HtmlService` houdt alleen UI- en editorstate en delegeert naar de store. Tijdens de migratie geven de oude getters (`probeResult`, `pageMetadata`, `browserProbeResult`, `resourceTimelineData`) een `toLegacyMap()` van de snapshots terug.
- Het primaire document voor DOM Tree, Metadata en Media is de rendered DOM als die er is, anders de server-body, anders het bestand. De keuze en de schakelaar (DOM/Server) staan in de store, niet in de widget.
- Bestaande code die hergebruikt wordt: `metadata_parser.dart extractMetadataInIsolate`, `detection/engine.dart detect`, `cookie_utils.dart` (lookup-tabel), `utils/page_weight.dart ResourceSize`, `HtmlService.sameResourceModuloCacheBusters` (verhuist naar `derive/resource_matching.dart`), `probe_service.dart extractCertificateInfo`, `SovereigntyService.analyze`, `certificate_security_service.dart`.
- Bestaande testpatronen: lokale `HttpServer` uit `test/services/probe_url_test.dart`, `test/detection_helpers.dart`, `test/utils/page_weight_test.dart`, `test/services/resource_matching_test.dart`.

## Teststrategie (lagen)

1. **Pure functies:** decoding, parsers en derivers, getest op fixtures (`test/fixtures/{server,browser,file}/`).
2. **Collectors:** `ServerFetcher` tegen een lokale `FixtureServer` (`test/support/fixture_server.dart`, routes → status/headers/bytes/vertraging). `BrowserPayload` op opgenomen JSON-payloads van echte apparaten (iOS, Android, macOS, Windows). `FileLoader` op byte-fixtures in een tijdelijke map.
3. **Store:** `InspectionStore` met bestuurbare fakes (Completers) voor de levenscyclus, stale-drops, volledige reset en het aantal notifies.
4. **Invarianten tussen de kernen:** totaal = som van de breakdown; resources uniek op genormaliseerde URL; server `finalUrl` ≠ browser `url` geeft een divergentie; geen `Present` met een verzonnen waarde.
5. **Widgets:** elke tab gepompt met een `PageInspection`-fixture via Provider. De getoonde tekst moet exact gelijk zijn aan de store, en `Unavailable` toont de melding (nooit 0, `N/A` of `null`).
6. **Architectuur-guard:** een test scant `lib/widgets` en `lib/screens` op verboden imports en aanroepen (`dart:io`, `package:http`, `html/parser`, `xml`, `HttpClient(`, `jsonDecode(`).

Commando's: `flutter analyze` (0 issues) en `flutter test` (alles groen, offline).

---

## Taken

Elke taak volgt TDD: eerst falende test(s) schrijven en zien falen, dan de minimale implementatie, dan zien slagen, dan `flutter analyze` en committen. Hieronder per taak alleen wat de uitvoerder niet zelf kan beslissen.

### Taak 1: Dode code weg, vangnet zetten

**Files:** verwijderen uit `html_service.dart`: `completeWebViewLoad`, `extractCurrentWebViewContent`, `updateWebViewUrl`. Verder verwijderen: `ProbeService.probeUrl` (`extractCertificateInfo` en `categorizeResource` blijven), `lib/services/shared_content_manager.dart`, `lib/services/platform_sharing_handler.dart`, de ongebruikte delen van `sharing_service.dart` (`handleSharedContent` en de legacy-takken), `lib/widgets/url_dialog.dart`. Tests die alleen deze code dekken: verwijderen of omzetten naar `UnifiedSharingService`.
- [ ] Zoek elke caller met grep; verwacht: 0 productie-callers.
- [ ] Pas `simple_tab_test` "Probe result is available after loading" en `tab_update_test` "loadFile should update cookies and metadata" aan. Een lokaal bestand mag **geen** probeResult hebben (dit legt B3 vast als falende test).
- [ ] Markeer die twee aangepaste tests met `skip: 'B3: nep-probe, gerepareerd in Taak 7'`, zodat CI groen blijft.
- [ ] `flutter test` + `flutter analyze` → groen. Commit.

### Taak 2: `Observed<T>` en `ObservedValue`-widget

**Files:** Create `lib/models/inspection/observed.dart`, `lib/widgets/observed_value.dart`; Test `test/models/observed_test.dart`, `test/widgets/observed_value_test.dart`.
**Produces:** de types uit Deel D; `ObservedValue<T>({required Observed<T> value, required String Function(T) format})`; `String unavailableMessage(UnavailableReason r, String detail)` met Nederlandse teksten per reden.
- [ ] Tests: `Present` rendert `format(value)` plus een bron-badge (browser/server/bestand); `Unavailable(blockedByPlatform, 'cross-origin zonder Timing-Allow-Origin')` rendert "Niet zichtbaar: …" en **nooit** `0`; `Pending` rendert een indicator; `Failed` rendert de foutmelding; `estimated` rendert de prefix "≈".
- [ ] Implementeren, groen, commit.

### Taak 3: Bytes en charset correct (B9, B14)

**Files:** Create `lib/utils/text_decoding.dart`; Test `test/utils/text_decoding_test.dart` + `test/fixtures/file/{utf8.html, latin1_meta.html, win1252_header.bin, utf16le_bom.txt, binary.png}`.
**Produces:** `DecodedText decodeText(List<int> bytes, {String? contentType})` met `text`, `charset`, `charsetSource` (`header`/`bom`/`meta`/`fallback`), `hadMalformed`, `isBinary`. Ondersteund: utf-8, utf-16le/be (BOM), iso-8859-1, windows-1252 (tabel voor 0x80-0x9F). Een onbekende charset geeft `charsetSource: fallback` en `hadMalformed`/`unsupportedCharset: true`.
- [ ] Tests: `'café'` in Latin-1 met `<meta charset=iso-8859-1>` → `café`, `charsetSource==meta`; header `charset=windows-1252` met byte 0x80 → `€`; een UTF-16LE-BOM-bestand correct; PNG → `isBinary==true`; charset `shift_jis` → `unsupportedCharset==true`; `byteLength` is altijd `bytes.length` (niet `text.length`).
- [ ] Implementeren, groen, commit.

### Taak 4: Server-kern: één `ServerFetcher`-keten (B1-deels, B15-B18, B29, B33, O5, O7, O8)

**Files:** Create `lib/services/collectors/server_fetcher.dart`, `lib/models/inspection/server_snapshot.dart`, `test/support/fixture_server.dart`; Test `test/collectors/server_fetcher_test.dart`.
**Interfaces:** `abstract class ServerFetcher { Future<ServerSnapshot> fetch(Uri url, {required String userAgent, int maxBytes = 10<<20}); }` met `IoServerFetcher` als implementatie. Die gebruikt GET met `followRedirects=false` en volgt redirects handmatig tot 5 hops. Per hop worden status, headers, Set-Cookie en `connectionInfo.remoteAddress` vastgelegd. De body wordt gestreamd tot `maxBytes` (`truncated`). Timeouts: connect 10 s, headers 15 s, body 30 s. Certificaat via `extractCertificateInfo`. Robots/sitemap komt in een aparte `fetchRobots(Uri origin)`, met resultaat in de snapshot.
- [ ] Tests tegen `FixtureServer`:
  - 301→302→200 met relatieve Location → 3 hops, `finalUrl` = laatste, body van de laatste;
  - http→https wordt als 2 hops gezien (niet "gelijk");
  - 6 hops → keten van 5 + `Unavailable(exceedsLimit)` op `finalUrl`;
  - redirect naar `file://` → keten afgebroken, met reden;
  - Set-Cookie op hop 1 en 3 → beide bewaard per hop;
  - chunked of gzip zonder Content-Length → `contentLength` is `Unavailable(notReportedByServer)` en `byteLength` = het aantal ontvangen bytes;
  - een body van 11 MB → `truncated==true`, eerste 10 MB aanwezig;
  - 403 met challenge-HTML → status 403 + body bewaard, `userAgent` vastgelegd;
  - een trage body → `Failed(timeout)` binnen de timeout;
  - `remoteAddress` = 127.0.0.1 (de socket, geen lookup).
- [ ] Implementeren, groen, commit.

### Taak 5: Browser-kern: één JS-collector + pure payload-parser (B8, B10-B13, B20, B22, O4)

**Files:** Create `lib/services/collectors/browser_payload.dart`, `lib/models/inspection/browser_snapshot.dart`, `lib/services/collectors/vsv_collect_js.dart` (het collector-script als const String). Wijzig `lib/widgets/browser_view.dart`: één `evaluateJavascript('__vsv_collect()')` geeft één JSON-payload terug. De debug-export bevat die ruwe payload, zodat fixtures van echte sites kunnen worden opgenomen. Tests: `test/collectors/browser_payload_test.dart` + `test/fixtures/browser/{ios_cross_origin_rtvutrecht.json, android_cache_hit.json, macos_basic.json, windows_nonstring.json, storage_security_error.json, page_with_pre.json, fetch_relative_dupes.json}`.
**Interfaces:** `BrowserSnapshot parseBrowserPayload(Object? raw, BrowserPlatform platform, {required Uri pageUrl})`. Storage, cookies en resources worden elk apart geparsed, met hun eigen `Observed`.
- [ ] Tests:
  - iOS-fixture: cross-origin resources met 0/0 → `Unavailable(blockedByPlatform)`, niet 0;
  - images op WebKit: `decoded` → `Unavailable(notReportedByPlatform)`;
  - Android cache-hit: transfer `Unavailable(servedFromCache)`, decoded behouden;
  - relatieve en absolute fetch-URL → 1 entry;
  - een fout bij storage → storage `Failed`, resources en cookies blijven intact;
  - een niet-String-resultaat (Windows) → `Unavailable(unsupportedPlatform)`;
  - een pagina met `<pre>` maar zonder DOCTYPE → DOM ongewijzigd (de unwrap alleen voor echte `text/plain`/JSON-documenten, bepaald via `document.contentType` in de payload);
  - `startTime`/`duration` behouden na een merge van refresh-payloads (`mergeResources(old, new)`);
  - cookies van `CookieManager` (iOS) behouden de flags; zonder flags (Android) → `Unavailable(notExposedToPage)`.
- [ ] Opnemen: draai de app op een iOS-simulator, Android-emulator en macOS tegen rtvutrecht.nl, een SPA en een site met localStorage, en sla de payloads op als fixtures (anonimiseer de cookiewaarden).
- [ ] Implementeren, groen, commit.

### Taak 6: File-kern (B14-file, B24, B31, B37-html_file, binair)

**Files:** Create `lib/services/collectors/file_loader.dart`, `lib/models/inspection/file_snapshot.dart`. Wijzig `toolbar.dart` (picker), `main.dart` (deep links), `unified_sharing_service.dart` zodat ze allemaal via `FileLoader` gaan. Test `test/collectors/file_loader_test.dart`, `test/unified_sharing_url_detection_test.dart` (aanvullen).
**Interfaces:** `Future<FileSnapshot> FileLoader.fromPath(String path, {required FileOrigin origin})`, `FileSnapshot FileLoader.fromBytes(List<int> bytes, {required String name, required FileOrigin origin})`, `FileSnapshot FileLoader.fromText(String text, {required FileOrigin origin})`. Elk pad gaat door `resolveWithinAppDirectories`.
- [ ] Tests:
  - Latin-1-bestand via het pad → correcte tekst (geen exception);
  - gedeelde bytes in UTF-8 → correct (niet via `fromCharCodes`);
  - PNG → `isBinary`, media-weergave;
  - een gedeeld pad buiten de app-directories → geweigerd;
  - picker/delen → `lastModified` is `Unavailable`, pad → `Present`;
  - gedeelde HTML-tekst die een URL bevat → blijft tekst;
  - alleen tekst die *geheel* één URL is, wordt een URL;
  - minified CSS (`a{b:c}.d{e:f}`) → blijft content;
  - `content://`-foutpagina → `isError`.
- [ ] Implementeren, groen, commit.

### Taak 7: `PageInspection` + `InspectionStore` met generatie-token (B3-B7, B19, B23, B29)

**Files:** Create `lib/models/inspection/page_inspection.dart`, `lib/services/inspection_store.dart`; Test `test/services/inspection_store_test.dart`.
**Interfaces:** `InspectionStore extends ChangeNotifier` met `PageInspection get current`, `int beginUrl(Uri url)`, `int beginFile(FileSnapshot f)`, `void applyServer(int gen, Observed<ServerSnapshot>)`, `void applyBrowser(int gen, BrowserSnapshot)`, `void setPrimaryDocument(DataSource s)`. Een store-mutatie geeft per aanroep hooguit 1 notify.
- [ ] Tests (fakes met Completers):
  - begin A, begin B, A's server-resultaat komt binnen → genegeerd, B blijft `Pending`;
  - A's browser-payload na B → genegeerd;
  - URL A volledig geladen, daarna `beginFile` → alle server- en browservelden `Unavailable(notApplicable)`, resources leeg, detecties zonder A-requests;
  - lokaal bestand → `server` is `Unavailable(notApplicable)`, er bestaat **geen** nep-probe (de B3-tests uit Taak 1 worden groen);
  - de browserkaart toont geen gekopieerde `serverStatusCode` meer: de status komt per bron uit de eigen snapshot;
  - één `applyBrowser` → precies 1 `notifyListeners`;
  - een probe-fout → `Failed` blijft zichtbaar (niet overschreven door een placeholder).
- [ ] Implementeren, groen, commit.

### Taak 8: Collectors aansluiten; `HtmlService` delegeert (B1, B2, B6, B21, B30, B36)

**Files:** Wijzig `html_service.dart` (`loadUrl`, `loadFile`, `clearFile`, `syncWebViewState`, `probeUrl`, `_loadFromUrlInternal`, `_loadSourceOnly` → vervangen door store-aanroepen; legacy-getters via `toLegacyMap()`), `browser_view.dart` (`onUpdateVisitedHistory` → `applyBrowser` met nieuwe URL), `main.dart` (`.value`-providers, `InspectionStore` toevoegen; dubbele probes weg), `sharing_service.dart:161`, `probe_views.dart:1056`. Test `test/services/html_service_lifecycle_test.dart`.
- [ ] Tests (met `FakeServerFetcher` + `FakeBrowserBridge`):
  - browser-first `loadUrl` → **zowel** `ServerFetcher.fetch` als het laden in de browser worden aangeroepen, en `server.body` is gevuld (B1);
  - source-first → `server.body` blijft na `loadFile` aanwezig (B2);
  - de Browser-tab openen in source-first → server-body ongewijzigd, DOM apart in `browser`;
  - een SPA-route-wissel → nieuwe browser-URL in de store;
  - een deep link → precies 1 fetch;
  - opnieuw syncen tijdens een lopende fetch → er blijft geen `isProbing` hangen.
- [ ] Bestaande tests (`file_loading_test`, `tab_*`, `url_*`, `redirect_*`) blijven groen of worden aangepast aan het correcte gedrag (dat expliciet in de commit-tekst zetten).
- [ ] Groen, commit.

### Taak 9: Afgeleide data op snapshots (B10, B20, B26-B28, B37-canonical, divergenties)

**Files:** Create `lib/services/derive/{metadata.dart, detections.dart, cookies.dart, page_weight.dart, resource_matching.dart}`. Hergebruik `metadata_parser.dart`, `detection/engine.dart`, `cookie_utils.dart`, `utils/page_weight.dart`. Wijzig `sovereignty_service.dart` (rcode, PSL-lite voor `registrableDomain`, security.txt-statussen, concurrency ≤ 6), `probe_service.dart:185` (RFC 4514-parse), `jurisdiction.dart` (bij CDN/OV-certificaat `derived` met een waarschuwing). Tests: per bestand in `test/derive/`, plus `test/services/sovereignty_service_test.dart` uitbreiden.
- [ ] Tests:
  - `deriveMetadata` met `<base href="https://cdn.x/">` → links worden daarop opgelost;
  - een lokaal bestand → relatieve links `Unavailable` ("niet op te lossen") in plaats van `https://img/a.png`;
  - `canonical` wordt gevuld vanuit `<link rel=canonical>`;
  - metadata weet op welk document het draaide (`docSource`);
  - `pageWeight`: afgeleid uit resources; totaal = som van de breakdown; iOS-images tellen met transfer; ontbrekende waarden maken het totaal `estimated` met "≥";
  - `mergeCookies`: sleutel = (naam, domein, pad); `Max-Age` wordt `expires`;
  - detecties: elke evidence draagt `DataSource`; een detectie alleen in de DOM (geïnjecteerd door JS) is gemarkeerd als "browser";
  - `divergences`: curl-status 403 tegenover een browser-pagina → divergentie "server gaf 403 aan curl-UA";
  - sovereignty: SERVFAIL → `unknown`, niet FAIL; `foo.github.io` → registrable `foo.github.io`;
  - certificaat `O=Example, Inc.` → intact.
- [ ] Implementeren, groen, commit.

### Taak 10: UI leest alleen uit de store; Observed overal (O1, B25, B35, alle "missing als echte waarde")

**Files:** Wijzig elke tab in `lib/widgets/` (source_viewer, dom_tree_view, metadata_view, media_view, page_size_view, services_view, privacy_view, sovereignty_view, request_timeline_view, probe_views, browser_view) en `lib/screens/home_screen.dart`. Dat gebeurt per tab in een eigen commit, met `Selector<InspectionStore, XViewModel>`. Parsen gaat naar `derive/`, `analyzeSovereignty` uit `build()` naar de store, `consumeTabSwitchRequest` uit `build()`. Source krijgt een schakelaar (Rendered DOM standaard | Server-HTML); de server-HTML toont een `Pending`/`Failed`-staat als die (nog) niet binnen is. Elke analysetab krijgt een bronlabel ("Bron: rendered DOM"). Tests: `test/widgets/<tab>_data_test.dart` per tab, uit gedeelde fixtures `test/fixtures/inspection/{full_page.dart, local_file.dart, ios_partial.dart, bot_blocked.dart}`.
- [ ] Per tab: (a) elke getoonde waarde is gelijk aan de fixture; (b) bij de `ios_partial`-fixture staat "Niet zichtbaar: …" en nergens `0 B`/`0 KB`; (c) bij `local_file` geen server-tabs en geen oude data; (d) een progress-tick (`webViewLoadingProgress`) veroorzaakt geen rebuild van de tab (teller in de test).
- [ ] Concreet vervangen:
  - "No Title" / "No description" → `Unavailable` (of "pagina heeft geen <title>", dat is een echte bevinding: onderscheid "afwezig in document" van "niet geëxtraheerd");
  - "none found" bij een mislukte extractie → `Failed`;
  - "null null" → `Pending`;
  - `0 (N bytes loaded)` → `Unavailable(notReportedByServer)`;
  - robots "0 disallow" zonder data → `Unavailable`;
  - een security-score van 0% zonder headers → `Pending`;
  - het lastModified van een gedeeld bestand in de export → `Unavailable`.
- [ ] DOM Tree: hoofdletterongevoelige DOCTYPE-check (B25), test met `<!doctype html>`.
- [ ] `LogoService`: niet-200 wordt kort (5 min) gecachet, niet voor de hele sessie (B35).
- [ ] `inspection_export_service.dart` exporteert `Observed` als `{status, value?, reason?, source, provenance}`, zodat de export dezelfde waarheid heeft als de UI.
- [ ] Groen, commit per tab.

### Taak 11: Architectuur-guard, privacy, adapters weg (B32, B34)

**Files:** Create `test/architecture/no_data_logic_in_ui_test.dart`. Wijzig `app_state_service.dart`/`html_service.dart:1166` (geen cookiewaarden en geen body's opslaan, alleen URL en UI-state; na restore opnieuw ophalen), `url_input.dart` + `home_screen.dart:136` (een lokaal bestand herladen via `FileSnapshot`, nooit `https://<naam>`). Verwijder `toLegacyMap()` en de oude map-getters zodra er geen callers meer zijn.
- [ ] Tests:
  - de guard: geen bestand onder `lib/widgets` of `lib/screens` importeert `dart:io`, `package:http`, `package:html/parser.dart` of `package:xml`, en geen enkel bestand bevat `HttpClient(` of `jsonDecode(` (met een expliciete allowlist met reden, bijvoorbeeld de file picker in de toolbar via `FileLoader`);
  - opgeslagen state bevat geen `analyzedCookies` en geen `value`-velden;
  - pull-to-refresh op een lokaal bestand → `FileLoader.fromPath`, niet `loadUrl`.
- [ ] `flutter analyze` (0 issues), `flutter test` (groen, offline), commit.

---

## Verificatie end-to-end

1. `flutter analyze` → 0 issues; `flutter test` → alles groen, zonder netwerk (draai het eens met wifi uit).
2. Handmatig op een iOS-simulator, Android-emulator en macOS. Vergelijk per site de export-JSON en de tabs:
   - **rtvutrecht.nl** (iOS): thumbnail-groottes zijn ~KB of "Niet zichtbaar", nooit MB of 0;
   - **een site met Cloudflare-challenge**: de curl-status en de browserstatus staan apart, met een divergentiemelding;
   - **http://github.com**: de redirect-keten toont 301 → https; de headers zijn van de eindpagina;
   - **een SPA** (bijvoorbeeld github.com: doorklikken): de URL en DOM volgen de route;
   - **een Latin-1-pagina** en een **Latin-1-bestand delen**: de tekens kloppen, de charset wordt getoond;
   - **na een URL een lokaal HTML-bestand openen**: Size, Timeline, Privacy en Services zijn leeg of n.v.t., niets van de vorige site;
   - **Source-tab**: standaard rendered DOM; "Server-HTML" geeft de echte curl-body (vergelijk die met `curl -A "<vastgelegde UA>" <url>`).
3. Controleer dat geen tab `0 B`, `N/A` of `null` toont waar de export-JSON `unavailable` zegt.

## Uitvoering

Aanbevolen: **subagent-driven**. Er zijn 11 taken met harde interfaces tussen model, store, collectors en UI. Een fout die erdoorheen glipt, betekent dat er onjuiste data aan gebruikers wordt getoond, dus een reviewer per taak is de kosten waard. Volgorde: 1 → 2 → 3 → 4/5/6 (onafhankelijk, kunnen parallel) → 7 → 8 → 9 → 10 (per tab) → 11.
