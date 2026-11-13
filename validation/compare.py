# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Compares the app's inspection packages with the reference measurements.

    uv run validation/compare.py validation/runs/<stamp>

Writes <run>/report.md and <run>/summary.json. Outcomes per check:
  ok        app matches the reference
  volatile  the two reference runs differ and the app is within them
  wrong     app value differs from the reference
  phantom   app reports something the reference does not see
  gap       app says unavailable/failed where the reference has a value
"""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

import yaml

HERE = Path(__file__).parent
SECURITY_HEADERS = [
    "strict-transport-security",
    "content-security-policy",
    "x-frame-options",
    "x-content-type-options",
    "referrer-policy",
    "permissions-policy",
]
DOMAINS = ["app", "redirects", "headers", "security", "certificate", "cookies",
           "browser", "metadata", "robots", "sovereignty", "detections", "consistency"]
RANK = {"ok": 0, "volatile": 1, "gap": 2, "phantom": 3, "wrong": 4}
ICON = {"ok": "✅", "volatile": "〰️", "gap": "⚠️", "phantom": "👻", "wrong": "❌"}


@dataclass
class Unavail:
    """An app value that is not present: status + reason from the export."""
    status: str
    reason: str = ""

    def __str__(self) -> str:
        return f"<{self.status}: {self.reason}>"


@dataclass
class Result:
    domain: str
    check: str
    outcome: str
    app: object
    ref: object
    evidence: str
    note: str = ""


@dataclass
class Site:
    slug: str
    results: list[Result] = field(default_factory=list)

    def add(self, domain, check, outcome, app, ref, evidence, note=""):
        self.results.append(Result(domain, check, outcome, app, ref, evidence, note))


# ---------------------------------------------------------------- app side

class App:
    def __init__(self, zip_path: Path):
        self.zip = zipfile.ZipFile(zip_path)

    def json(self, name: str):
        try:
            return json.loads(self.zip.read(name))
        except KeyError:
            return None

    def value(self, name: str, *keys):
        """The present value at keys, or Unavail with the export's reason."""
        node = self.json(name)
        for k in (None, *keys):
            if isinstance(node, dict) and "status" in node and "value" not in node \
                    and node.get("status") != "present":
                return Unavail(node["status"], node.get("detail") or node.get("reason", ""))
            if isinstance(node, dict) and node.get("status") == "present" and "value" in node:
                node = node["value"]
            if k is None:
                continue
            if not isinstance(node, dict) or k not in node:
                return Unavail("missing", f"{name}:{'.'.join(map(str, keys))}")
            node = node[k]
        if isinstance(node, dict) and node.get("status") == "present" and "value" in node:
            node = node["value"]
        elif isinstance(node, dict) and node.get("status") in ("unavailable", "failed", "pending"):
            return Unavail(node["status"], node.get("detail") or node.get("reason", ""))
        return node


# ---------------------------------------------------------------- comparing

def compare_exact(app, refs: list):
    refs = [r for r in refs if r is not None]
    if not refs:
        return "ok" if isinstance(app, Unavail) or app in (None, [], False) else "phantom"
    if isinstance(app, Unavail):
        return "gap"
    if all(r == refs[0] for r in refs):
        return "ok" if app == refs[0] else "wrong"
    return "volatile" if app in refs else "wrong"


def compare_set(app, refs: list[set]):
    refs = [r for r in refs if r is not None]
    if isinstance(app, Unavail):
        return ("gap" if any(refs) else "ok"), ""
    app = set(app)
    union = set().union(*refs) if refs else set()
    inter = set.intersection(*refs) if refs else set()
    missing, extra = inter - app, app - union
    note = []
    if missing:
        note.append(f"missing in app: {sorted(missing)}")
    if extra:
        note.append(f"only in app: {sorted(extra)}")
    if missing:
        return "wrong", "; ".join(note)
    if extra:
        return "phantom", "; ".join(note)
    return ("volatile" if union != inter else "ok"), ""


def compare_num(app, refs: list, rel: float):
    """Within rel of the reference range (both runs), else wrong."""
    refs = [r for r in refs if r is not None]
    if not refs:
        return "ok"
    if isinstance(app, Unavail):
        return "gap"
    lo, hi = min(refs) * (1 - rel), max(refs) * (1 + rel)
    if not lo <= app <= hi:
        return "wrong"
    return "volatile" if min(refs) != max(refs) and not min(refs) <= app <= max(refs) else "ok"


def jaccard(a: set, b: set) -> float:
    return 1.0 if not a and not b else len(a & b) / len(a | b)


def last_headers(ref) -> dict:
    return ref["hops"][-1]["headers"] if ref and ref["hops"] else {}


# Mozilla HTTP Observatory: HSTS counts from six months; these referrer
# policies do not leak the full URL cross-origin.
HSTS_MIN = 15552000
GOOD_REFERRER = {"no-referrer", "same-origin", "strict-origin",
                 "strict-origin-when-cross-origin", "origin", "origin-when-cross-origin"}
KNOWN_REFERRER = GOOD_REFERRER | {"no-referrer-when-downgrade", "unsafe-url"}


def referrer_good(value: str) -> bool:
    """The last recognised token wins (fallback lists)."""
    tokens = [t.strip() for t in value.replace(",", " ").split() if t.strip() in KNOWN_REFERRER]
    return bool(tokens) and tokens[-1] in GOOD_REFERRER


def sec_checks(headers: dict, https: bool) -> dict[str, bool]:
    """Independent pass/fail for the app's header checks (not CSP quality)."""
    h = {k: " ".join(v).lower() for k, v in headers.items()}
    csp = h.get("content-security-policy", "")
    hsts = re.search(r"max-age=(\d+)", h.get("strict-transport-security", ""))
    out = {
        "Frames": "x-frame-options" in h or "frame-ancestors" in csp,
        "No Sniff": h.get("x-content-type-options", "").strip() == "nosniff",
        "Referrer": referrer_good(h.get("referrer-policy", "")),
        "Permissions": "permissions-policy" in h,
    }
    if https:
        out["HSTS"] = bool(hsts and int(hsts.group(1)) >= HSTS_MIN)
    return out


def check_site(site: Site, app: App, refs: list[dict], meta: dict, conf: dict):
    r1 = refs[0] if refs else None

    # Completeness of the app run itself.
    pending = meta.get("pendingAtExport", [])
    site.add("app", "finished before export",
             "wrong" if pending or meta.get("error") else "ok",
             pending or meta.get("error") or "complete", "complete", "app-meta.json",
             f"waited {meta.get('waitedMs')} ms")

    # Redirects and status.
    hops = app.value("network/probe.json", "hops")
    app_chain = hops if isinstance(hops, Unavail) else [(h["url"], h["statusCode"]) for h in hops]
    ref_chains = [[(h["url"], h["statusCode"]) for h in r["hops"]] for r in refs]
    site.add("redirects", "chain (url, status)", compare_exact(app_chain, ref_chains),
             app_chain, ref_chains[0] if ref_chains else None, "network/probe.json")

    # Header presence on the final hop.
    hh = app.value("network/headers.json", "hops")
    app_final = {} if isinstance(hh, Unavail) or not hh else hh[-1]["headers"]
    for name in SECURITY_HEADERS + ["content-encoding"]:
        a = hh if isinstance(hh, Unavail) else name in app_final
        site.add("headers", name, compare_exact(a, [name in last_headers(r) for r in refs]),
                 a, name in last_headers(r1), "network/headers.json")

    # Security scorecard inputs.
    checks = app.value("analysis/security-scorecard.json", "audit", "checks")
    https = (r1 or {}).get("finalUrl", "").startswith("https")
    ref_checks = [sec_checks(last_headers(r), https) for r in refs]
    for label in ["HSTS", "Frames", "No Sniff", "Referrer", "Permissions"]:
        if not any(label in rc for rc in ref_checks):
            continue
        if isinstance(checks, Unavail):
            a = checks
        else:
            match = [c for c in checks if c["label"] == label]
            a = match[0]["passing"] if match else Unavail("missing", label)
        site.add("security", f"check {label}", compare_exact(a, [rc.get(label) for rc in ref_checks]),
                 a, ref_checks[0].get(label) if ref_checks else None,
                 "analysis/security-scorecard.json")

    # Certificate.
    cert = app.value("analysis/certificate.json")
    rc = [r.get("certificate") for r in refs]
    if any(rc) or not isinstance(cert, Unavail):
        def a(f):
            return cert if isinstance(cert, Unavail) else f(cert)
        site.add("certificate", "issuer CN",
                 compare_exact(a(lambda c: c["issuer"].get("Common Name")),
                               [c and c["issuerCN"] for c in rc]),
                 a(lambda c: c["issuer"].get("Common Name")), rc[0] and rc[0]["issuerCN"],
                 "analysis/certificate.json")
        site.add("certificate", "valid until (date)",
                 compare_exact(a(lambda c: (c.get("validUntil") or "")[:10]),
                               [c and c["notAfter"][:10] for c in rc]),
                 a(lambda c: c.get("validUntil")), rc[0] and rc[0]["notAfter"],
                 "analysis/certificate.json", "app shows local time; date compared")
        site.add("certificate", "host matches (ref: SAN)",
                 compare_exact(a(lambda c: "matches host" in c.get("host", "").lower()),
                               [c and c["hostMatches"] for c in rc]),
                 a(lambda c: c.get("host")), rc[0] and rc[0]["hostMatches"],
                 "analysis/certificate.json")

    # Cookies set by the server (browser cookies need the browser reference).
    cookies = app.value("network/cookies.json", "cookies")
    ref_server = [{c["name"]: c for h in r["hops"] for c in h["setCookies"]} for r in refs]
    if isinstance(cookies, Unavail):
        app_server = cookies
    else:
        app_server = {c["name"]: c for c in cookies if "Server" in str(c.get("source", ""))}
    outcome, note = compare_set(
        app_server if isinstance(app_server, Unavail) else set(app_server),
        [set(r) for r in ref_server])
    site.add("cookies", "Set-Cookie names", outcome,
             app_server if isinstance(app_server, Unavail) else sorted(app_server),
             sorted(ref_server[0]) if ref_server else None, "network/cookies.json", note)
    if not isinstance(app_server, Unavail) and ref_server:
        for name in sorted(set(app_server) & set(ref_server[0])):
            ac, rcook = app_server[name], ref_server[0][name]
            browser_ss = {c["name"]: (c.get("sameSite") or "").lower()
                          for c in (refs[0].get("browser") or {}).get("cookies", [])}
            for flag, av, rv in [
                ("Secure", ac.get("secure") == "yes", rcook["secure"]),
                ("HttpOnly", ac.get("httpOnly") == "yes", rcook["httpOnly"]),
                ("SameSite", "(not set)" if str(ac.get("sameSite", "")).lower().startswith("not set")
                 else str(ac.get("sameSite", "")).lower(),
                 (rcook["sameSite"] or "(not set)").lower()),
            ]:
                ok = av == rv or (flag == "SameSite" and rv == "(not set)"
                                  and av not in ("none", "(not set)")
                                  and browser_ss.get(name) == av)
                # The other reference run got another header: the site varies.
                other = [r.get(name) for r in ref_server[1:] if name in r]
                key = {"Secure": "secure", "HttpOnly": "httpOnly", "SameSite": "sameSite"}[flag]
                varies = any((o[key] or "(not set)").lower() == av if flag == "SameSite"
                             else o[key] == av for o in other)
                outcome = "ok" if ok else "volatile" if varies else "wrong"
                site.add("cookies", f"{name} {flag}", outcome, av, rv,
                         "network/cookies.json",
                         f"reference browser: {browser_ss.get(name)}" if flag == "SameSite" else "")

    # robots.txt and sitemaps.
    rb = app.value("analysis/robots-sitemap.json")
    rr = [r["robots"] for r in refs]
    a_present = rb if isinstance(rb, Unavail) else str(rb.get("robots", "")).endswith("200")
    site.add("robots", "robots.txt present", compare_exact(a_present, [r["present"] for r in rr]),
             a_present, rr[0]["present"] if rr else None, "analysis/robots-sitemap.json",
             "" if isinstance(rb, Unavail) else f"app fetched {rb.get('robotsUrl')}")
    if not isinstance(rb, Unavail) and rr and rr[0]["present"]:
        outcome, note = compare_set(set(rb.get("sitemaps") or []), [set(r["sitemaps"]) for r in rr])
        site.add("robots", "sitemaps", outcome, len(rb.get("sitemaps") or []),
                 len(rr[0]["sitemaps"]), "analysis/robots-sitemap.json", note)
        m = re.match(r"(\d+)", str(rb.get("disallow", "")))
        site.add("robots", "disallow count",
                 compare_exact(int(m.group(1)) if m else Unavail("missing", "disallow"),
                               [r["disallowCount"] for r in rr]),
                 rb.get("disallow"), rr[0]["disallowCount"], "analysis/robots-sitemap.json")

    # Browser: cookies, storage, resources, page weight.
    brs = [r.get("browser") for r in refs if r.get("browser")]
    if brs:
        all_names = [{c["name"] for c in b["cookies"]} | set(srv)
                     for b, srv in zip(brs, ref_server)]
        app_names = cookies if isinstance(cookies, Unavail) else {c["name"] for c in cookies}
        outcome, note = compare_set(app_names, all_names)
        site.add("browser", "cookie names (browser + server)", outcome,
                 app_names if isinstance(app_names, Unavail) else len(app_names),
                 len(all_names[0]), "network/cookies.json", note)
        for area in ("local", "session"):
            a = app.value("network/browser-probe.json", "storage", area, "count")
            refs_n = [b["storage"][area] for b in brs]
            # Ad and A/B scripts add or drop a few keys per load.
            close = (not isinstance(a, Unavail)
                     and all(abs(a - n) <= max(2, 0.2 * n) for n in refs_n))
            site.add("browser", f"{area}Storage keys (±2 or 20%)",
                     "ok" if close else compare_exact(a, refs_n), a,
                     brs[0]["storage"][area], "network/browser-probe.json")
        a = app.value("network/browser-probe.json", "resourceCount")
        site.add("browser", "resource count (±20%)",
                 compare_num(a, [b["resourceEntryCount"] for b in brs], 0.2), a,
                 brs[0]["resourceEntryCount"], "network/browser-probe.json",
                 f"ref requests incl. document: {brs[0]['requestCount']}")
        a = app.value("analysis/page-weight.json", "transfer")
        lower = app.value("analysis/page-weight.json", "transferLowerBound") is True
        outcome = compare_num(a, [b["transferBytes"] for b in brs], 0.5)
        if outcome == "wrong" and lower and a <= max(b["transferBytes"] for b in brs):
            outcome = "ok"  # the app says it is a lower bound, and it is one
        site.add("browser", "transfer bytes (±50%)", outcome, a,
                 brs[0]["transferBytes"], "analysis/page-weight.json",
                 "app: lower bound" if lower else "")
        tl = app.value("network/timeline.json")
        if isinstance(tl, Unavail):
            site.add("browser", "request hosts", "gap", tl, len(brs[0]["hosts"]),
                     "network/timeline.json")
        else:
            app_hosts = {re.sub(r"^https?://([^/:]+).*", r"\1", e["url"]) for e in tl}
            ref_hosts = set().union(*[set(b["hosts"]) for b in brs])
            j = jaccard(app_hosts, ref_hosts)
            site.add("browser", "request hosts (Jaccard ≥ 0.6)", "ok" if j >= 0.6 else "wrong",
                     len(app_hosts), len(ref_hosts), "network/timeline.json",
                     f"J={j:.2f}; only app: {sorted(app_hosts - ref_hosts)[:8]}; "
                     f"only ref: {sorted(ref_hosts - app_hosts)[:8]}")

        # Metadata from the rendered DOM.
        md = app.value("analysis/metadata.json")
        for key in ("title", "description", "canonical"):
            a = md if isinstance(md, Unavail) else md.get(key)
            site.add("metadata", key, compare_exact(a, [b["metadata"][key] for b in brs]),
                     a, brs[0]["metadata"][key], "analysis/metadata.json")
        if not isinstance(md, Unavail):
            outcome, note = compare_set(set((md.get("openGraph") or {}).items()),
                                        [set(b["metadata"]["openGraph"].items()) for b in brs])
            site.add("metadata", "og:* tags", outcome, len(md.get("openGraph") or {}),
                     len(brs[0]["metadata"]["openGraph"]), "analysis/metadata.json", note)
        sd = app.value("analysis/structured-data.json")
        if isinstance(sd, Unavail):
            types = sd
        else:
            types, stack = set(), list(sd)
            while stack:
                it = stack.pop()
                if isinstance(it, dict):
                    t = it.get("@type")
                    types.update(t if isinstance(t, list) else [t] if t else [])
                    stack.extend(it.get("@graph", []))
                elif isinstance(it, list):
                    stack.extend(it)
        outcome, note = compare_set(types, [set(b["metadata"]["jsonLdTypes"]) for b in brs])
        site.add("metadata", "JSON-LD @types", outcome,
                 types if isinstance(types, Unavail) else sorted(types),
                 brs[0]["metadata"]["jsonLdTypes"], "analysis/structured-data.json", note)

    # Sovereignty inputs (the score formula itself is audited separately).
    infra = [r.get("infrastructure") for r in refs if r.get("infrastructure")]
    sov = app.value("analysis/sovereignty.json")
    if infra:
        if isinstance(sov, Unavail):
            site.add("sovereignty", "report", "gap", sov, "measured", "analysis/sovereignty.json")
        else:
            host_check = next((c for c in sov.get("checks", [])
                               if c.get("title", "").startswith("Hosting company")), None)
            evidence = (host_check or {}).get("evidence", "")
            cdn = re.search(r"served through ([^;(]+?)(?: \(|;)", evidence)
            if cdn:
                # The app names the CDN instead of the hidden origin: the
                # main host's AS holder must be that CDN.
                word = cdn.group(1).split()[0].lower()
                holder = (infra[0]["asName"] or "").lower()
                site.add("sovereignty", "CDN = AS holder of main host",
                         "ok" if word in holder else "wrong", cdn.group(1),
                         infra[0]["asName"], "analysis/sovereignty.json", evidence)
            else:
                m = re.search(r"AS(\d+)", evidence)
                a_asn = int(m.group(1)) if m else Unavail("missing", "no AS in hosting check")
                site.add("sovereignty", "hosting AS",
                         compare_exact(a_asn, [i["asn"] for i in infra]),
                         a_asn, infra[0]["asn"], "analysis/sovereignty.json", evidence)
                c = (re.search(r"registered in (\w\w)", evidence)
                     or re.search(r"\((\w\w)\)$", (host_check or {}).get("title", "")))
                a_cc = c.group(1) if c else Unavail("missing", "no AS country in evidence")
                site.add("sovereignty", "hosting AS country",
                         compare_exact(a_cc, [i["asCountry"] for i in infra]), a_cc,
                         infra[0]["asCountry"], "analysis/sovereignty.json")
            for key in ("nameServers", "mailServers"):
                recs = {r["record"].lower().rstrip(".") for r in sov.get(key) or []}
                outcome, note = compare_set(recs, [set(i[key]) for i in infra])
                site.add("sovereignty", key, outcome, sorted(recs), infra[0][key],
                         "analysis/sovereignty.json", note)

    check_consistency(site, app)

    # Detections against hand-made ground truth.
    det = app.json("analysis/detections.json") or {}
    names = {d["name"] for d in det.get("value", [])}
    for name in conf.get("expect_detections") or []:
        site.add("detections", f"expect {name}", "ok" if name in names else "wrong",
                 name in names, True, "analysis/detections.json")
    for name in conf.get("forbid_detections") or []:
        site.add("detections", f"forbid {name}", "phantom" if name in names else "ok",
                 name in names, False, "analysis/detections.json")


# ---------------------------------------------------------------- consistency

TRACKING = {"advertising", "behavior", "social", "analytics", "marketing"}


def check_consistency(site: Site, app: App):
    """Pages of the app that judge the same thing must agree (no reference
    needed): Cookie Lens <-> Services <-> Sovereignty privacy pillar."""
    det = (app.json("analysis/detections.json") or {}).get("value", [])
    cookies = app.value("network/cookies.json", "cookies")
    sov = app.value("analysis/sovereignty.json")

    # 1. Every tracking cookie in the Cookie Lens is claimed by a service.
    if not isinstance(cookies, Unavail):
        claimed = {c for d in det for c in d.get("cookies", [])} | {
            e["title"].removeprefix("Cookie ") for d in det
            for e in d.get("evidence", []) if e.get("kind") == "cookie"}
        orphans = sorted(c["name"] for c in cookies
                         if c.get("category") in ("advertising", "analytics", "social")
                         and c.get("provider") and c["name"] not in claimed)
        site.add("consistency", "tracking cookies are Services detections",
                 "wrong" if orphans else "ok", orphans or "all claimed", "[]",
                 "network/cookies.json", "Cookie Lens vs analysis/detections.json")

    if isinstance(sov, Unavail):
        return
    checks = {c["title"]: c for c in sov.get("checks", [])}

    def names(title):
        ev = (checks.get(title) or {}).get("evidence", "")
        return set() if ev in ("", "None detected") else {n.strip() for n in ev.split(", ")}

    # 2. Sovereignty counts the trackers the Privacy tab lists.
    if "Number of trackers" in checks:
        privacy = {d["name"] for d in det if d["category"] in TRACKING}
        sv = names("Number of trackers")
        site.add("consistency", "Privacy tab trackers = Sovereignty trackers",
                 "ok" if sv == privacy else "wrong", len(sv), len(privacy),
                 "analysis/sovereignty.json",
                 f"only Privacy: {sorted(privacy - sv)}; only Sovereignty: {sorted(sv - privacy)}"
                 if sv != privacy else "")

    # 3. The consent tool Services found is the one Sovereignty names.
    consent = {d["name"] for d in det if d["category"] == "consent"}
    if consent and "Consent management" in checks:
        sv = names("Consent management")
        site.add("consistency", "consent tool: Services = Sovereignty",
                 "ok" if sv == consent else "wrong", sorted(sv), sorted(consent),
                 "analysis/sovereignty.json")

    # 4. The grade is the band of the score (80 / 50, lib/services/derive/score_band.dart).
    score, grade = sov.get("score"), sov.get("grade")
    if score is not None:
        want = "Good" if score >= 80 else "Fair" if score >= 50 else "Poor"
        site.add("consistency", "Sovereignty grade matches score",
                 "ok" if grade == want else "wrong", f"{score} {grade}", want,
                 "analysis/sovereignty.json")


# ---------------------------------------------------------------- report

def fmt(v) -> str:
    s = str(v) if not isinstance(v, str) else v
    s = s.replace("|", "\\|").replace("\n", " ")
    return s if len(s) <= 160 else s[:157] + "…"


def report(run_dir: Path, sites: list[Site]) -> str:
    domains = sorted({r.domain for s in sites for r in s.results},
                     key=lambda d: DOMAINS.index(d) if d in DOMAINS else 99)
    out = [f"# Validation report — {run_dir.name}", "",
           "✅ ok · 〰️ volatile · ⚠️ gap · 👻 phantom · ❌ wrong", "",
           "| site | " + " | ".join(domains) + " |",
           "|---|" + "---|" * len(domains)]
    for s in sites:
        cells = []
        for d in domains:
            rs = [r for r in s.results if r.domain == d]
            worst = max((r.outcome for r in rs), key=RANK.get, default=None)
            bad = sum(1 for r in rs if RANK[r.outcome] >= 2)
            cells.append("" if worst is None else ICON[worst] + (f" {bad}" if bad else ""))
        out.append(f"| {s.slug} | " + " | ".join(cells) + " |")
    out += ["", "## Deviations", ""]
    for s in sites:
        devs = [r for r in s.results if RANK[r.outcome] >= 2]
        if not devs:
            continue
        out += [f"### {s.slug}", "", "| | domain | check | app | reference | evidence | note |",
                "|---|---|---|---|---|---|---|"]
        for r in devs:
            out.append(f"| {ICON[r.outcome]} | {r.domain} | {fmt(r.check)} | {fmt(r.app)} | "
                       f"{fmt(r.ref)} | `{s.slug}/app.zip:{r.evidence}` | {fmt(r.note)} |")
        out.append("")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--sites", type=Path, default=HERE / "sites.yaml")
    args = ap.parse_args()
    conf = {s["slug"]: s for s in yaml.safe_load(args.sites.read_text())["sites"]}

    sites = []
    for site_dir in sorted(p for p in args.run_dir.iterdir() if p.is_dir()):
        zip_path = site_dir / "app.zip"
        if not zip_path.exists():
            continue
        refs = [json.loads(p.read_text()) for p in sorted(site_dir.glob("ref-R*.json"))]
        meta_path = site_dir / "app-meta.json"
        meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
        site = Site(site_dir.name)
        check_site(site, App(zip_path), refs, meta, conf.get(site_dir.name, {}))
        sites.append(site)

    (args.run_dir / "report.md").write_text(report(args.run_dir, sites))
    summary = {
        s.slug: {f"{r.domain}/{r.check}": r.outcome for r in s.results} for s in sites
    }
    (args.run_dir / "summary.json").write_text(json.dumps(summary, indent=2))
    totals = {}
    for s in sites:
        for r in s.results:
            totals[r.outcome] = totals.get(r.outcome, 0) + 1
    print(f"{len(sites)} sites: {totals} -> {args.run_dir / 'report.md'}")


if __name__ == "__main__":
    main()
