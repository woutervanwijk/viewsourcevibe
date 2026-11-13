# Audit: berekeningen en data achter de analysepagina's (nov 2026)

Gecontroleerd: **Security Headers Score** (incl. CSP-score en certificaat), **Header Intelligence**, **Cookie Privacy Lens** en **Sovereignty**. Per berekening: wat hij doet, waarop hij is gebaseerd, en het oordeel na toetsing aan externe standaarden en aan de andere pagina's.

Oordelen: **klopt** · **fout** (geeft een verkeerd antwoord) · **misleidend** (technisch te verdedigen, maar de gebruiker leest iets anders) · **ontwerpkeuze** (gewicht/drempel zonder externe norm; besluit nodig) · **data** (bron onjuist of verouderd).

## 1. Inventaris

### 1.1 Security Headers Score — `lib/services/derive/security_audit.dart`
- Invoer: headers van de laatste hop van de eigen server-fetch (`ServerSnapshot.hops.last`).
- Zes checks met gelijk gewicht: HSTS (alleen bij HTTPS van toepassing), CSP, Frames (X-Frame-Options of CSP `frame-ancestors`), No Sniff (`contains('nosniff')`), Referrer-Policy, Permissions-Policy.
- Score = `round(geslaagd / van-toepassing × 100)`; null als niets van toepassing is.
- UI-kleur (`lib/widgets/probe_views.dart`): ≥80 goed, ≥50 matig, anders slecht.

### 1.2 CSP-score — `security_audit.dart` `_csp`
- Elke policy (herhaalde header of komma-gescheiden) apart; directives via `split(';')`.
- Bevindingen: high = `'unsafe-inline'` of `'unsafe-eval'` in script-src (fallback default-src); medium = `*` in default/script-src, object-src niet `'none'`, geen `base-uri`, geen `frame-ancestors`.
- Score per policy = `clamp(100 − 22·high − 12·medium)`; getoonde score = zwakste policy. UI-drempels 80/50.

### 1.3 Certificaat — `security_audit.dart` `_certificate`
- Geldigheid: <0 dagen verlopen, <14 slecht, <45 waarschuwing, anders goed.
- Hostmatch: alleen subject Common Name, wildcard `*.` met gelijk aantal labels.

### 1.4 Header Intelligence — `lib/services/derive/header_insights.dart`
- Cache: `no-store` → warn; `max-age ≥ 86400` → "Cacheable", anders "Short cache"; geen → neutraal.
- Compressie: geen `Content-Encoding` → warn.
- CDN: Cloudflare (`server`/`cf-cache-status`), "hit" in server/via/x-cache, `via`/`x-cache` → proxy; anders "Origin-ish".
- CORS: `*` + credentials → bad; `*` → warn; anders good.
- Vary (aantal waarden), validators (ETag/Last-Modified).
- Notes: Content-Type ontbreekt, nosniff exact ≠ `nosniff`, `server`/`x-powered-by` aanwezig, chunked zonder Content-Length (max 4).

### 1.5 Cookie Privacy Lens — `lib/services/derive/cookies_view.dart`, `cookies.dart`, `lib/utils/cookie_utils.dart`
- Cookies = Set-Cookie van alle hops ∪ browsercookies, samengevoegd op (naam, domein, pad).
- Categorie via naam: `_knownCookies` (~1660 namen, deels Open Cookie Database), prefix-sleutels op `_`/`-`, detectiecatalogus (`entityForCookie`), "consent" in naam → essential.
- Score = `clamp(100 − 12·advertising − 7·analytics − 6·social − 3·onbekend − 6·cross-site-achtig − 5·zwakke SameSite − 2·niet-Secure)`; berekend zodra er ≥1 cookie is of beide bronnen bekend zijn.
- Verdict: ≥75 laag, ≥45 matig, anders zwaar.

### 1.6 Sovereignty — `lib/services/sovereignty_service.dart`, `lib/services/jurisdiction.dart`, `lib/services/derive/sovereignty_view.dart`
- Pijlers met maximum: infrastructuur 40, dataresidentie 25, beveiliging 20, privacy 15.
- Per check: pass 1, warn 0,5, fail 0; gewicht 3 (essentieel), 2, 1, 0,5. Unknown telt niet mee.
- Pijlerscore = max × gewogen gemiddelde; totaal = som / som van maxima van verifieerbare pijlers; Good ≥80, Fair ≥50.
- Data: providerlijst met landen (regex op hostnaam/ASN-houder/uitgever), RIPEstat (ASN, ASN-registratieland, GeoLite-locatie), DoH (NS, MX, SPF, DMARC, CAA, DS), security.txt-status, detectiecatalogus (vendor-landen), EU/EER- en adequaatheidslijst, extraterritoriale wetten, mini public-suffixlijst.

## 2. Bevindingen

Elke bevinding is eerst aangetoond met een falende test (of, waar dat niet kan, met codeverwijzing/bron). Status: **fix** = opgelost in deze branch met test · **besluit** = vraagt een productkeuze · **ok** = verworpen, klopt.

### 2.1 Security Headers Score
| # | Oordeel | Bevinding | Norm | Status |
|---|---|---|---|---|
| S1 | fout | Alleen aanwezigheid telt: HSTS `max-age=0`, `Referrer-Policy: unsafe-url`, `X-Frame-Options: ALLOWALL` en een CSP met alleen `upgrade-insecure-requests` slagen. | OWASP Secure Headers, Mozilla HTTP Observatory, RFC 7034 | fix |
| S2 | fout | Op een HTTP-pagina valt HSTS uit de noemer, dus een site zonder HTTPS haalt 100%. | RFC 6797, Observatory | fix |
| S3 | fout | nosniff: audit gebruikt `contains` (accepteert `nonsniff-nosniffx`), Header Intelligence exacte vergelijking (waarschuwt bij `nosniff, nosniff`) → pagina's spreken elkaar tegen. | Fetch spec "determine nosniff" | fix |

### 2.2 CSP-score
| # | Oordeel | Bevinding | Norm | Status |
|---|---|---|---|---|
| C1 | fout | `'unsafe-inline'` telt als high, ook met nonce/hash/`'strict-dynamic'` (dan negeert de browser hem). | CSP Level 3 | fix |
| C2 | fout | `object-src` valt niet terug op `default-src`; `default-src 'none'` krijgt toch een medium-bevinding. | CSP Level 3 fallback | fix |
| C3 | fout | Wildcard-check ziet alleen `*`, niet `https:`, `http:`, `data:` of `*.domein`. | Google CSP Evaluator | fix |
| C4 | fout | Dubbele directive: laatste wint, spec zegt eerste. | CSP Level 3 parsing | fix |
| C5 | misleidend | Ontbrekende `frame-ancestors` kost 12 punten ook als X-Frame-Options al beschermt. | — | fix (→ low) |
| C6 | fout | `script-src-elem`/`script-src-attr` genegeerd; alleen `script-src` werd beoordeeld. | CSP Level 3 | fix (follow-up) |
| — | ontwerpkeuze | Gewichten 22/12 en drempels 80/50 hebben geen externe norm. | — | besluit |

### 2.3 Certificaat
| # | Oordeel | Bevinding | Status |
|---|---|---|---|
| T1 | misleidend | Hostmatch alleen op CN; SAN wordt niet verzameld (Dart `X509Certificate` biedt het niet). Browsers kijken alleen naar SAN (RFC 9525) → valse "CN differs from host". | fix (label + neutrale toon); SAN uit DER parsen = besluit |

### 2.4 Header Intelligence
| # | Oordeel | Bevinding | Norm | Status |
|---|---|---|---|---|
| H1 | fout | `no-cache`/`private` → "No cache policy"; `no-cache, max-age=86400` → "Cacheable"; `s-maxage` genegeerd; korte HTML-cache krijgt waarschuwing. | RFC 9111 §5.2 | fix |
| H2 | ok (deels) | App vraagt wél `gzip, deflate` en bewaart `Content-Encoding`; alleen br/zstd worden niet gevraagd. | — | fix (tekst) |
| H3 | fout | `server: Whitehall` → "Cache hit" (substring `hit`); CDN-regels wijken af van Sovereignty (Vercel/Netlify/Akamai/`cf-ray` → "Origin-ish"). | — | fix (gedeelde detectie) |

### 2.5 Cookie Privacy Lens
| # | Oordeel | Bevinding | Status |
|---|---|---|---|
| K1 | fout | Dubbeltelling: één `_fbp` kost 12 + 6, één `_ga` 7 + 6 (categorie én "cross-site"). | fix |
| K2 | fout | "Cross-site" = Domain met leidende punt (RFC 6265: betekenisloos) of provider met "Google" in de naam (34 essentiële Google-cookies zoals `CONSENT`, `SOCS`). | fix |
| K3 | fout | Ontbrekende SameSite telt als zwak, terwijl browsers Lax aannemen; tekst zegt "strict". | fix |
| K4 | fout | Ontbrekend Secure wordt ook op HTTP-pagina's bestraft. | fix |
| K5 | misleidend | Score/verdict bij onvolledige bronnen zonder voorbehoud in het verdict. | fix |
| K7 | fout | Elke naam met "consent" wordt essential (`consent_ad_id`, `trackingconsent_ads`). | fix |
| K8 | fout | Prefix-match: eerste i.p.v. langste wint; 4 specifieke prefixen onbereikbaar (`_gac_gb_`, `_vis_opt_exp_`, …). | fix |
| K9 | fout | `Max-Age=0` (= verwijderen) en verlopen/ongeldige `Expires` niet herkend. | fix |
| K10 | ok | Was een valse bevinding: RFC 6265 §5.2 splitst de Set-Cookie-string bij de eerste `;`, quotes zijn niet speciaal. Huidig gedrag klopt; test legt het vast. | geen fix nodig |
| K11 | ontwerpkeuze | `NID`/`IDE` bewust als eigen cookie behandeld (niet-onderscheidende naam). | besluit |
| — | ontwerpkeuze | Gewichten 12/7/6/3/6/5/2 en drempels 75/45. | besluit |

### 2.6 Cookie-database (data)
- Bron: Open Cookie Database, upstream commit van 2026-11-06, licentie **Apache-2.0**. De app bevat 2293 namen (niet ~1660): 1838 uit OCD (op 3 na gelijk), 455 handmatig.
- **Licentie**: geen naamsvermelding/licentietekst in de app (Apache-2.0 vereist dat). Los daarvan: `LICENSE` is GPLv3, README en About-scherm zeggen MIT. → **besluit**.
- **Wildcards**: 132 OCD-wildcardregels zonder `_`/`-` zijn als exacte naam overgenomen (bv. `_gat` matcht `_gat_UA-123` niet); omgekeerd worden 15 exacte OCD-namen die op `_` eindigen als prefix behandeld.
- 95 categorie-afwijkingen (bijna allemaal in het handmatige deel), o.a. Facebook `c_user`/`datr`/`xs` en Adobe `AMCV_` als essential.
- 251 OCD-namen ontbreken (vooral Nexx360); grote platforms zijn compleet.
- Categorie `social` bevat 2 namen; social-platformcookies staan als advertising/functional → teller "social" is vrijwel altijd 0.
- Advies (**besluit**): Dart-map genereren uit een gepinde OCD-CSV met expliciet wildcard-veld, handmatige overrides apart, en een NOTICE toevoegen.

### 2.7 Sovereignty — berekening
| # | Oordeel | Bevinding | Norm | Status |
|---|---|---|---|---|
| V1 | fout | DMARC `sp=none; p=reject` → warn (regex vindt `sp=`). | RFC 7489 §6.3 | fix |
| V2 | fout | SPF: `include:foo-all…` telt als `-all`; meerdere SPF-records (permerror) en `v=spf1x` niet herkend; `+all -all` → pass. | RFC 7208 | fix |
| V3 | ok | TXT-strings worden correct aaneengeplakt. | RFC 7208 §3.3 | — |
| V4 | fout | security.txt: elke HTTP 200 (ook soft-404 HTML) telt als gepubliceerd. | RFC 9116 | fix |
| V5 | fout | Registreerbaar domein fout voor `go.kr`, `gob.mx`, `gouv.fr`, `nhs.uk`, `me.uk`, … → DNS-checks op de verkeerde zone. | Public Suffix List | fix (heuristiek) |
| V6 | fout | Providerherkenning op substrings: `lawsociety` → AWS, `novhotels` → OVH, `ionosphere` → IONOS, … | — | fix |
| V7 | fout | `x-served-by` + `x-cache` → Fastly; `gws` als substring → Google; S3-origin-header telt als CDN. | — | fix |
| V8 | misleidend | Score herschaalt over verifieerbare checks; met alleen security/privacy bekend → 100 "Good". Dekking nergens zichtbaar. | — | fix (dekking tonen) |
| V9 | fout | "Geen CDN gedetecteerd" = pass, ook als er geen headers waren. | — | fix |
| V10 | ontwerpkeuze | TLS-CA buiten eigen jurisdictie altijd warn (adequaat = buitenlands). | — | besluit |
| V11 | misleidend | Residentie-check rekent alleen over hosts met bekende locatie (1 van 10 kan "100%" geven); headline gaat over bedrijfsjurisdictie zonder dat te zeggen; afkapping op 40 hosts onzichtbaar. | — | fix |
| V12 | fout | Afronding: 1 op 1001 → "0% gaat naar buiten", 999 op 1000 → "100% onbekend". | — | fix |
| V13 | data | "Wederzijdse adequaatheid" toegepast op CA, NZ, KR (niet formeel); GB↔CH niet gemodelleerd. | — | fix |
| V14 | fout | Privacylink: "Cookie settings"-knop (`href="#"`) en `cookiebar.js` tellen; links zonder quotes gemist. | — | fix |
| V15 | fout | Trackers niet ontdubbeld: 3× dezelfde detectie → "fail". | — | fix |
| — | ontwerpkeuze | Pijlers 40/25/20/15, checkgewichten, Good ≥80 / Fair ≥50. | — | besluit |

### 2.8 Sovereignty — data
| Data | Was | Wordt | Bron |
|---|---|---|---|
| Adequaatheid | — | + BR (wederzijdse besluiten jan 2026) | Europese Commissie, adequacy decisions |
| `_genericCcTlds` | `is` generiek | verwijderd (.is = IJsland, EER) | — |
| Imperva | US | FR (Thales, dec 2023) | Thales persbericht |
| Sectigo | GB | US (HQ Scottsdale) | — |
| GlobalSign | BE | JP (GMO Internet Group) | — |
| Heap | US | FR (Contentsquare) | Contentsquare persbericht |
| Smartlook | CZ | US (Cisco) | Cisco acquisitions |
| Adjust | DE | US (AppLovin) | — |
| Hotjar / Cookiebot / CookieFirst / Ezoic / Trustpilot | MT / DK / BE / GB / DK | FR / DE / NL / US / GB | — |
| Google Fonts-bron | "LG München (2022) ruled … violates the GDPR" | LG München I, 20-01-2022, 3 O 17493/20, IP-adres zonder toestemming, €100 | — |

Geverifieerd en correct: EU/EER-lijst, overige adequaatheidslanden, extraterritoriale wetten, overige providerlanden, alle 22 alternatieven-URL's.
Discutabel (niet gewijzigd): TikTok (CN vs SG/IE), Taboola/OpenWeb (US/IL), Klarna (GB/SE), Teads, CookieYes (GB/IN), Piano Analytics (FR), `self-hosted` voor cloudversies (Matomo Cloud, Ghost(Pro)).

### 2.9 Consistentie tussen pagina's
Vastgelegd in `test/derive/cross_page_consistency_test.dart`: dezelfde response geeft hetzelfde oordeel op elke pagina.
| Feit | Pagina's | Was | Nu |
|---|---|---|---|
| HSTS | Security ↔ Sovereignty | Sovereignty: aanwezig = pass (ook `max-age=0`, ook op HTTP) | gedeelde `hstsMaxAge`/`hstsMinSeconds` (6 mnd); 1 dag–6 mnd = warn |
| nosniff | Security ↔ Headers | `contains` vs exact | gedeelde `isNosniff` |
| CDN | Headers ↔ Sovereignty | eigen regels per pagina | Headers gebruikt `detectCdnFromHeaders` |

Neveneffect van V6 (hele woorden): samengestelde hostnamen zoals `googletagmanager`, `googlesyndication`, `cdninstagram`, `akamaihd`, `cloudflareinsights` staan nu expliciet in de patronen (matchten voorheen via substring). Bewust nog wél een match: namen waarin `-` een woordgrens is (`gcp-pharma.nl`, `comodo-pizza.nl`).

### 2.10 Follow-up (na PR #44)
- **C6** opgelost (`script-src-elem`, `script-src-attr`).
- **K10** was geen bug (zie boven).
- **Cookie-database** opnieuw opgebouwd: `tool/gen_cookie_db.dart` genereert `lib/utils/cookie_db.g.dart` uit de gepinde OCD-CSV (`tool/data/`, commit 7786335, 2026-11-06). Wildcard komt uit het OCD-veld (niet meer uit een `_`/`-`-suffix), langste prefix wint, wildcards korter dan 3 tekens matchen exact. Handmatige kennis staat apart in `lib/utils/cookie_overrides.dart` (275 namen die niet in OCD staan). Voor namen in OCD wint OCD; 108 van de 2293 oude namen kregen een andere categorie (o.a. Google `SID`-familie en Facebook `c_user` → advertising). Tien OCD-namen zonder wildcardvlag waar het echte cookie een id achter de naam zet (`Hm_lvt_<id>`) staan in `forcedWildcard`.
- **Social**: 19 cookies via regel (platform in Facebook/Instagram/LinkedIn/Pinterest/TikTok/X en omschrijving over delen/plugin/login, zonder advertentie-woorden); pixel- en advertentiecookies blijven advertising.
- **Licentie-attributie**: Apache-2.0 tekst van OCD in `assets/licenses/`, geregistreerd in de licentiepagina van de app (About → Open source licenses) en in `THIRD_PARTY_NOTICES.md`. De projectlicentie zelf (GPLv3 vs MIT) is nog open.
- **Te weinig data → geen score**: Sovereignty toont geen score of cijfer onder 50% dekking (`SovereigntyReport.minCoverage`); Cookie Privacy Lens toont alleen een score als zowel de Set-Cookie-headers als de browsercookies gelezen zijn. De Security Headers Score en de CSP-score hebben altijd een response nodig en tonen anders al niets.

## 3. Besluiten voor jou
1. **Gewichten en drempels** van alle vier scores (geen externe norm): houden, of afleiden van Observatory (security) en documenteren.
2. ~~Cookie-database~~ gedaan (follow-up).
3. **Licenties**: OCD-naamsvermelding gedaan; GPLv3 vs MIT rechttrekken is open.
4. **SAN** uit het certificaat (DER) parsen, zodat de hostcheck echt klopt.
5. **TLS-CA-check** (V10): adequaat warn / buitenlands fail, of lager gewicht.
6. ~~Lage dekking~~ gedaan: score verborgen onder 50% dekking.
