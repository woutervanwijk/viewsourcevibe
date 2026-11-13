# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml", "playwright", "beautifulsoup4"]
# ///
"""Independent reference measurement for the validation harness.

Measures every site of a run with other tools than the app (curl, openssl,
Playwright WebKit, BeautifulSoup, dig, Team Cymru whois) and writes <run>/<slug>/ref-<label>.json. Uses the app's own User-Agent
(read from app.zip) so bot protection answers both the same way.

    uv run validation/reference.py validation/runs/<stamp> --label R1
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlsplit

MAX_HOPS = 10
TIMEOUT = 20


def sh(args: list[str], stdin: str | None = None, timeout: int = TIMEOUT) -> str:
    try:
        return subprocess.run(
            args, input=stdin, capture_output=True, text=True, timeout=timeout
        ).stdout
    except subprocess.TimeoutExpired:
        return ""


def parse_headers(raw: str) -> tuple[int | None, dict[str, list[str]]]:
    """The last header block of a curl -D dump (skips 1xx/100-continue)."""
    blocks = [b for b in re.split(r"\r?\n\r?\n", raw.strip()) if b.startswith("HTTP/")]
    if not blocks:
        return None, {}
    lines = blocks[-1].splitlines()
    m = re.match(r"HTTP/\S+\s+(\d{3})", lines[0])
    headers: dict[str, list[str]] = {}
    for line in lines[1:]:
        if ":" in line:
            k, v = line.split(":", 1)
            headers.setdefault(k.strip().lower(), []).append(v.strip())
    return (int(m.group(1)) if m else None), headers


def parse_set_cookie(line: str) -> dict:
    parts = [p.strip() for p in line.split(";")]
    name = parts[0].split("=", 1)[0].strip()
    attrs = {}
    for p in parts[1:]:
        k, _, v = p.partition("=")
        attrs[k.strip().lower()] = v.strip()
    return {
        "name": name,
        "domain": attrs.get("domain"),
        "path": attrs.get("path"),
        "secure": "secure" in attrs,
        "httpOnly": "httponly" in attrs,
        "sameSite": attrs.get("samesite"),
    }


def hops(url: str, ua: str) -> list[dict]:
    out = []
    for _ in range(MAX_HOPS):
        dump = sh([
            "curl", "-sS", "-o", "/dev/null", "-D", "-", "--max-redirs", "0",
            "--compressed", "-A", ua, "-m", str(TIMEOUT),
            "-w", "\n\nVSVMETA %{http_code} %{remote_ip}", url,
        ])
        meta = re.search(r"VSVMETA (\d+) (\S*)", dump)
        status, headers = parse_headers(dump.split("VSVMETA")[0])
        hop = {
            "url": url,
            "statusCode": status or (int(meta.group(1)) if meta else None),
            "remoteAddress": meta.group(2) if meta and meta.group(2) else None,
            "headers": headers,
            "setCookies": [parse_set_cookie(c) for c in headers.get("set-cookie", [])],
        }
        out.append(hop)
        loc = headers.get("location")
        if not (status and 300 <= status < 400 and loc):
            break
        url = urljoin(url, loc[0])
    return out


def certificate(host: str) -> dict | None:
    pem = sh(["openssl", "s_client", "-connect", f"{host}:443", "-servername", host],
             stdin="")
    if "BEGIN CERTIFICATE" not in pem:
        return None
    text = sh(["openssl", "x509", "-noout", "-subject", "-issuer", "-startdate",
               "-enddate", "-ext", "subjectAltName", "-nameopt", "RFC2253"], stdin=pem)

    def field(prefix: str) -> str | None:
        m = re.search(rf"^{prefix}=?(.*)$", text, re.M)
        return m.group(1).strip() if m else None

    def cn(dn: str | None) -> str | None:
        m = re.search(r"CN=([^,]+)", dn or "")
        return m.group(1) if m else None

    def date(s: str | None) -> str | None:
        if not s:
            return None
        d = datetime.strptime(s, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
        return d.isoformat()

    sans = re.findall(r"DNS:([^,\s]+)", text)
    subject, issuer = field("subject"), field("issuer")
    return {
        "subject": subject,
        "subjectCN": cn(subject),
        "issuer": issuer,
        "issuerCN": cn(issuer),
        "notBefore": date(field("notBefore")),
        "notAfter": date(field("notAfter")),
        "san": sans,
        "hostMatches": any(
            s.lower() == host.lower()
            or (s.startswith("*.") and host.lower().split(".", 1)[-1] == s[2:].lower())
            for s in sans
        ),
    }


def robots(final_url: str, ua: str) -> dict:
    u = urlsplit(final_url)
    url = f"{u.scheme}://{u.netloc}/robots.txt"
    dump = sh(["curl", "-sS", "-L", "--compressed", "-A", ua, "-m", str(TIMEOUT),
               "-w", "\nVSVSTATUS %{http_code}", url])
    m = re.search(r"\nVSVSTATUS (\d+)$", dump)
    status = int(m.group(1)) if m else None
    body = dump[: m.start()] if m else ""
    ok = status == 200 and "<html" not in body[:500].lower()
    return {
        "url": url,
        "status": status,
        "present": ok,
        "sitemaps": re.findall(r"(?im)^[ \t]*sitemap:[ \t]*(\S+)", body) if ok else [],
        # [ \t] not \s: an empty "Disallow:" must not reach the next line.
        "disallowCount": len(re.findall(r"(?im)^[ \t]*disallow:[ \t]*\S", body)) if ok else 0,
    }


BROWSER_QUIET_S = 5
BROWSER_MAX_S = 30


def browser(url: str) -> dict:
    """Cold WebKit load like the app's WKWebView: no consent clicked, network
    watched until 5 s without new requests (max 30 s), then cookies, storage,
    requests and the rendered DOM."""
    import time

    from bs4 import BeautifulSoup
    from playwright.sync_api import sync_playwright

    requests: list[dict] = []
    with sync_playwright() as pw:
        b = pw.webkit.launch()
        ctx = b.new_context(viewport={"width": 1280, "height": 900})
        page = ctx.new_page()

        def on_response(resp):
            try:
                size = resp.request.sizes()["responseBodySize"]
            except Exception:
                size = None
            requests.append({"url": resp.url, "status": resp.status, "bytes": size})

        page.on("response", on_response)
        try:
            page.goto(url, wait_until="load", timeout=45000)
        except Exception as e:  # keep what loaded
            error = str(e)
        else:
            error = None
        start, last, seen = time.time(), time.time(), len(requests)
        while time.time() - start < BROWSER_MAX_S and time.time() - last < BROWSER_QUIET_S:
            page.wait_for_timeout(1000)
            if len(requests) != seen:
                seen, last = len(requests), time.time()
        final = page.url
        storage = page.evaluate(
            "() => ({local: Object.keys(localStorage).length,"
            " session: Object.keys(sessionStorage).length})")
        resource_count = page.evaluate(
            "() => performance.getEntriesByType('resource').length")
        html = page.content()
        cookies = [
            {k: c.get(k) for k in ("name", "domain", "path", "secure", "httpOnly", "sameSite")}
            for c in ctx.cookies()
        ]
        b.close()

    soup = BeautifulSoup(html, "html.parser")

    def meta(attr: str, key: str) -> str | None:
        tag = soup.find("meta", attrs={attr: key})
        return tag.get("content") if tag else None

    link = soup.find("link", rel=lambda v: v and "canonical" in v)
    ld_types: set[str] = set()
    for tag in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(tag.string or "")
        except ValueError:
            continue
        stack = data if isinstance(data, list) else [data]
        while stack:
            item = stack.pop()
            if isinstance(item, dict):
                t = item.get("@type")
                ld_types.update(t if isinstance(t, list) else [t] if t else [])
                stack.extend(item.get("@graph", []))
            elif isinstance(item, list):
                stack.extend(item)
    page_host = urlsplit(final).hostname or ""
    return {
        "error": error,
        "finalUrl": final,
        "cookies": cookies,
        "storage": storage,
        "requestCount": len(requests),
        "resourceEntryCount": resource_count,
        "transferBytes": sum(r["bytes"] or 0 for r in requests),
        "hosts": sorted({urlsplit(r["url"]).hostname or "" for r in requests} - {""}),
        "pageHost": page_host,
        "metadata": {
            "title": soup.title.string.strip() if soup.title and soup.title.string else None,
            "description": meta("name", "description"),
            "canonical": link.get("href") if link else None,
            "openGraph": {
                t["property"]: t.get("content")
                for t in soup.find_all("meta", attrs={"property": re.compile(r"^og:")})
            },
            "jsonLdTypes": sorted(ld_types),
        },
    }


def dig(name: str, rtype: str) -> list[str]:
    """Targets of the records of exactly this type (a CNAME in the answer is
    skipped); the null MX "0 ." (no mail) gives no entry."""
    out = []
    for line in sh(["dig", "+noall", "+answer", rtype, name]).splitlines():
        f = line.split()
        if len(f) >= 5 and f[3] == rtype:
            target = f[-1].rstrip(".")
            if target:
                out.append(target)
    return out


def cymru(query: str) -> list[str]:
    lines = sh(["whois", "-h", "whois.cymru.com", f" -v {query}"]).splitlines()
    return [c.strip() for c in lines[1].split("|")] if len(lines) > 1 else []


def infrastructure(host: str) -> dict:
    """Hosting AS of the main host, and the NS/MX records of its zone."""
    ips, asn, as_info = [], [], []
    for _ in range(3):  # dig and whois occasionally come back empty
        ips = ips or [i for i in dig(host, "A") if re.match(r"^\d+\.\d+\.\d+\.\d+$", i)]
        asn = asn or (cymru(ips[0]) if ips else [])
        as_info = as_info or (cymru(f"AS{asn[0]}") if asn else [])
        if as_info:
            break
    # The site's own domain (last two labels; enough for the sites we test),
    # not a delegated www zone or a CNAME target.
    zone = ".".join(host.split(".")[-2:])
    ns, mx = dig(zone, "NS"), dig(zone, "MX")
    return {
        "host": host,
        "ip": ips[0] if ips else None,
        "asn": int(asn[0]) if asn and asn[0].isdigit() else None,
        "asName": as_info[4] if len(as_info) > 4 else None,
        "asCountry": as_info[1] if len(as_info) > 1 else None,
        "zone": zone,
        "nameServers": sorted(n.lower() for n in ns),
        "mailServers": sorted(m.lower() for m in mx),
    }


def app_info(zip_path: Path) -> tuple[str, str]:
    with zipfile.ZipFile(zip_path) as z:
        manifest = json.loads(z.read("manifest.json"))
        probe = json.loads(z.read("network/probe.json"))
    url = manifest["source"]["path"]
    ua = (probe.get("value") or {}).get("userAgent") or "curl"
    return url, ua


def site_origin_url(chain: list[dict]) -> str:
    """The last hop still on the requested site's domain (skips a redirect to
    a consent host such as myprivacy.dpgmedia.nl)."""
    first = (urlsplit(chain[0]["url"]).hostname or "").removeprefix("www.")
    for hop in reversed(chain):
        if (urlsplit(hop["url"]).hostname or "").endswith(first):
            return hop["url"]
    return chain[-1]["url"]


def measure(url: str, ua: str) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    chain = hops(url, ua)
    final = chain[-1]["url"]
    host = urlsplit(final).hostname or ""
    return {
        "url": url,
        "userAgent": ua,
        "measuredAt": started,
        "hops": chain,
        "finalUrl": final,
        "certificate": certificate(host) if final.startswith("https") else None,
        "robots": robots(site_origin_url(chain), ua),
        "browser": browser(url),
        "infrastructure": infrastructure(host),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--label", default="R1")
    args = ap.parse_args()
    for site_dir in sorted(p for p in args.run_dir.iterdir() if p.is_dir()):
        zip_path = site_dir / "app.zip"
        if not zip_path.exists():
            print(f"skip {site_dir.name}: no app.zip", file=sys.stderr)
            continue
        url, ua = app_info(zip_path)
        ref = measure(url, ua)
        out = site_dir / f"ref-{args.label}.json"
        out.write_text(json.dumps(ref, indent=2))
        print(f"{site_dir.name}: {len(ref['hops'])} hops -> {out}")


if __name__ == "__main__":
    main()
