# Site-validatie: triage (13 nov 2026)

Tien echte sites zijn door de app gehaald (`validation/run.sh`, zie `validation/README.md`). Elke export is vergeleken met een onafhankelijke meting: curl, openssl, Playwright WebKit, dig en Team Cymru, telkens twee keer. De eerste run gaf ~40 afwijkingen. Per afwijking: oordeel, oorzaak en wat ermee is gedaan.

Oordelen: **app-bug** · **harness** (de referentie of vergelijker zat fout) · **site** (de site gedraagt zich zo) · **platform** (een grens van WKWebView of iOS/macOS).

## App-bugs (gefixt, met test)

| # | Bevinding | Site(s) | Oorzaak | Fix | Test |
|---|---|---|---|---|---|
| A1 | Certificaat "CN differs from host" terwijl de SAN-lijst de host bevat | rtvutrecht | Alleen de Common Name werd vergeleken (zie ook audit nov 2026) | SAN (OID 2.5.29.17) uit de PEM gelezen; label zegt nu of CN of SAN matchte | `test/derive/security_audit_test.dart` met het echte certificaat (`test/fixtures/certs/rtvutrecht.pem`) |
| A2 | Dezelfde cookie zonder SameSite heette "None" (zwak, −5 in de cookiescore) als de browser hem ook zag, en "not set (Lax by default)" als alleen de server hem zag | kvk, wikipedia | WebKit meldt een ontbrekende SameSite als `None`; bij het samenvoegen won die waarde | Header zonder SameSite + browser `None` blijft "not set"; een echte browserwaarde (bv. Lax via JS) blijft staan | `test/derive/cookies_test.dart` (groep SameSite) |
| A3 | Null-MX (`0 .`, RFC 7505) verscheen als lege mailserver en werd als host opgezocht | example.com | DNS-parser nam de lege naam op | Null-MX wordt overgeslagen | `test/services/sovereignty_service_test.dart` |
| A4 | De CMS-check in Sovereignty toonde ruwe bronfragmenten als evidence | github | `detail` (bronfragment) in plaats van `title` | `title` ("HTML line 414: …") | — (alleen tekst) |
| A5 | Een tracker die alleen via een later binnengekomen cookie werd gevonden, stond wel op Services maar niet in de privacypijler van Sovereignty | rijksoverheid | Sovereignty rekende alleen opnieuw als het aantal resources veranderde | De detectienamen horen nu bij de invoersleutel | `test/services/sovereignty_state_test.dart` |
| A6 | Privacy-tab ("7 trackers follow you") en Sovereignty ("Number of trackers: 6") telden verschillend | allbirds, techcrunch | Privacy telt social widgets als tracker, Sovereignty niet | Besluit: social widgets zijn trackers op beide pagina's. Sovereignty-check heet nu "Trackers in the site's jurisdiction"; de oude widgets-check is "Payments & e-commerce" (geen dubbeltelling) | `test/derive/privacy_consistency_test.dart` |
| A7 | In de export ontbrak de koppeling cookie → service als de evidence-lijst (max. 12) vol zat | allbirds (`_gcl_au`) | Alleen evidence werd geëxporteerd | `cookies` per detectie staat nu in `analysis/detections.json` | `test/derive/privacy_consistency_test.dart` |
| A8 | Kleurdrempels van de scorekaarten stonden los in de widgets (80/50, 75/45) | — | Dubbele drempels in model en UI | `lib/services/derive/score_band.dart` is de enige bron; `bandColor()` voor de kleur | `test/derive/score_band_test.dart` (grenzen + geen losse drempels in de widgets) |

## Open (niet gefixt)

| # | Bevinding | Oordeel | Voorstel |
|---|---|---|---|
| O1 | bol.com: ook de WebView van de app kreeg Akamai's blokpagina ("IP address is blocked"), terwijl Playwright vanaf hetzelfde IP de echte site kreeg. De app analyseert de blokpagina als de site, en de divergentiemelding zegt ten onrechte "the browser loaded the page". | app-bug | De browser-status van het hoofddocument meten (`PerformanceNavigationTiming.responseStatus`) en een blok-/challengepagina markeren in plaats van analyseren. Dit is review-punt 2 uit het plan van 6 nov. |
| O2 | De app ziet soms minder cookies dan Playwright: kvk 6 van 7 (`IDHUB_JSESSIONID`), rijksoverheid wisselend 1 of 5 (Piwik `_pk_*`, `stg_*`). In een eerdere run met 25 s wachttijd klopte rijksoverheid wel. | site/platform | Meerdere app-runs per site draaien om het als volatiel te kunnen labelen; mogelijk ITP van WKWebView of steekproefsgewijze surveyscripts |
| O3 | Paginagewicht wijkt fors af op advertentiesites (techcrunch 25 MB tegen 6 MB) | site | Alleen als signaal (±50%); geen fout |

## Harness-correcties (de app had gelijk)

- HSTS en Referrer-Policy: de app volgt de drempels van Mozilla Observatory (HSTS ≥ 6 maanden; `no-referrer-when-downgrade` lekt). De referentie gebruikt nu dezelfde norm.
- robots.txt: curl volgde de consent-redirect van ad.nl. Daarnaast telde de regex lege `Disallow:`-regels mee omdat `\s` ook een newline matcht.
- NS/MX: gemeten op de CNAME of op een gedelegeerde www-zone in plaats van op het domein zelf.
- Hosting achter een CDN: de app noemt bewust de CDN in plaats van de verborgen origin. De check is nu "CDN = AS-houder".
- Browserdata: de eerste runs exporteerden direct na "settled". Met 20 s extra wachttijd (`VSV_LINGER`, standaard in `run.sh`) komen cookies, storage en hosts overeen.

## Consistentiechecks (nieuw)

Pagina's die hetzelfde beoordelen moeten hetzelfde zeggen. Dat wordt nu op twee niveaus getest:

- **Offline (Dart)**: `test/derive/privacy_consistency_test.dart` controleert vijf dingen. Elke trackingcookie uit de Cookie Lens is een Services-detectie. Cookie en service zijn het eens over het soort tracking. De eigen cookie van de site is nergens een tracker. Privacy en Sovereignty tellen dezelfde trackers. De consent-tool is dezelfde. Daarnaast: `test/derive/score_band_test.dart` en de bestaande `cross_page_consistency_test.dart` (HSTS, nosniff, CDN).
- **Op echte exports**: `compare.py` heeft het domein `consistency` met dezelfde invarianten, plus de controle dat de Sovereignty-grade bij de score hoort.

## Eindstand

| Run | ok | volatiel | ❌ |
|---|---|---|---|
| Eerste (13 nov, 08:34), voor triage | 336 | 6 | 78 (incl. gaten en fantomen) |
| Laatste (13 nov, 09:32), na fixes | 418 | 7 | 16 |

De resterende 16: tien komen door bol.com (O1). De andere zes zijn browservariatie op advertentie- en surveysites (O2, O3). Consistentie is op alle tien sites groen.
