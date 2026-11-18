# Privacy Policy for View Source Vibe

**Last updated: November 16, 2026**

View Source Vibe ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how our application handles your information.

## Data Collection and Use

**We do not collect, store, share, or sell any personal data.**

View Source Vibe functions entirely locally on your device. The application allows you to view the source code of websites and extract metadata. All processing of HTML, RSS feeds, and other content happens directly on your device.

- **No Account Required:** You do not need to create an account to use the app.
- **No Analytics:** We do not use third-party analytics services to track your usage.
- **No Tracking:** We do not track your browsing history or search queries.

## Network Access

The application contacts:

1. **The site you inspect**: the page itself (in the in-app browser and with a separate request by the app), its redirects, `robots.txt`, `sitemap.xml` and, once the Sovereignty tab has been opened, `/.well-known/security.txt`.
2. **The hosts that page loads files from**: the in-app browser loads them like any browser. For files whose size the browser does not report, the app requests the file once more to measure it. Known tracking pixels, and third-party images that look like pings, are not requested again. If you start a "fresh load", the app loads the page and its third-party files again in an off-screen browser.
3. **RIPEstat (stat.ripe.net, RIPE NCC, Netherlands)**: the IP addresses of the hosts a page uses, to look up their network and country. Only after you open the Sovereignty tab. Once opened, the analysis also runs for the pages you open next during that session.
4. **A DNS-over-HTTPS resolver** (doh.libredns.gr, Greece; dns.google, United States, as fallback): the domain name of the site, to read its DNS records, and the host names on the site's own domain that the page loads (at most 20), to see whether any is an alias for a tracker. Only after you open the Sovereignty tab, as above, or the Privacy tab.
5. **Your device's DNS resolver** (usually your internet provider's or the one set in your operating system): the app looks up the IP address of every host a page uses, so this resolver sees those host names. The in-app browser also uses it for every page it loads, whether or not you open the Sovereignty tab; the app's own lookups of all hosts a page uses happen only after you open it, as above.
6. **DuckDuckGo's icon service (icons.duckduckgo.com)**: the domain names of services detected on a page, to show their logos. Logos are cached for 30 days.

These services see your IP address and the names listed above. They do not receive the page content, your history or cookies. RIPEstat sees the app name `viewsourcevibe` with each request, which is the same for every user and says nothing about you.

Your history and the URLs you visit are stored on your device and are never sent to us.

## Plain HTTP and TLS

View Source Vibe can open plain `http://` URLs on purpose: inspecting the source of non-HTTPS sites is core functionality of the app. On Android this is enabled via `network_security_config.xml` (`cleartextTrafficPermitted`), on Apple platforms via `NSAllowsArbitraryLoads`. This does **not** weaken HTTPS: TLS certificates for `https://` connections are strictly validated against the system trust store. If a server presents an invalid or untrusted certificate, the app asks you explicitly before accepting it, and that acceptance only lasts for the current session. Within the in-app browser only `http:` and `https:` navigation is allowed; `data:`, `blob:`, `file:`, `javascript:` and other schemes are blocked.

## Changes to This Policy

We may update our Privacy Policy from time to time. Thus, you are advised to review this page periodically for any changes. We will notify you of any changes by posting the new Privacy Policy on this page.

## Contact Us

If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us.
