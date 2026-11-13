# Site validation

Checks whether what the app reports about real sites is true. The app loads
each site in `sites.yaml` and exports its inspection package; independent
tools measure the same site twice; a comparer lists only the differences.

```bash
validation/run.sh              # all sites, ~10–15 min
validation/run.sh example kvk  # some slugs
```

Needs: macOS, Flutter, [uv](https://docs.astral.sh/uv/), and once
`uv run --with playwright playwright install webkit`.

## What happens

1. **App pass** — `integration_test/site_validation_test.dart` starts the real
   app (debug, macOS), clears cookies and cache, loads each URL, waits until
   the page is settled and every analysis is done (max 90 s), and writes
   `runs/<stamp>/<slug>/app.zip` (the normal export) plus `app-meta.json`.
2. **Reference R1 and R2** — `reference.py` measures every site without the
   app's code: curl (redirects, headers, Set-Cookie, robots.txt, with the
   app's own User-Agent), openssl (certificate), Playwright WebKit (cookies,
   storage, requests, rendered DOM → BeautifulSoup metadata), dig and Team
   Cymru whois (hosting AS, NS, MX). Two runs show what varies by itself.
3. **Compare** — `compare.py` writes `runs/<stamp>/report.md` (site × domain
   matrix, then every deviation with both values and the file in the zip) and
   `summary.json` (to diff runs before and after a fix).

Neither side clicks a consent banner: both measure the pre-consent page.

## Outcomes

| | meaning |
|---|---|
| ✅ ok | app matches the reference |
| 〰️ volatile | R1 and R2 differ and the app is within them |
| ⚠️ gap | app says unavailable where the reference has a value — check the reason; a real platform limit is correct behaviour |
| 👻 phantom | app reports something the reference does not see |
| ❌ wrong | app value differs |

The comparer checks *inputs* (headers, cookies, hosts, records) exactly and
scores only indirectly; the score formulas are audited in
`docs/audits/2026-11-berekeningen.md`.

## Triage

Classify each ❌/👻/⚠️ as **app bug**, **reference limit**, **site variation**
or **platform limit**. Only app bugs become work:

1. Copy `debug/browser-payload.json` from the zip to
   `test/fixtures/browser/<slug>.json` (and headers to a fixture in
   `test/fixtures/inspection/` if the server side is involved).
2. Write a failing offline test in `test/derive/` or `test/collectors/`.
3. Fix, `flutter test`, rerun `validation/run.sh <slug>` and compare
   `summary.json` with the previous run.

## Adding a site or check

- Site: add an entry to `sites.yaml` with `why`, and set
  `expect_detections` / `forbid_detections` by checking the site once by
  hand (Wappalyzer/BuiltWith in a normal browser). Names must match the
  app's detection names.
- Check: measure the value in `reference.py`, add a line in
  `compare.py:check_site` with `compare_exact`, `compare_set` or
  `compare_num`.
