# Changelog

All notable, user-facing changes to View Source Vibe are documented here.

## 1.3.0

### New
- **Reader** tab (HTML pages): renders the page as a clean article using Readability.js, extracted from the live browser view when available. Links in the article open in the Browser tab.
- **Size** tab: "Fresh load" measurement — reloads the page with an empty cache on a phone-sized viewport and shows both loads side by side, each with its own verdict. Third-party iframes are labelled.
- Settings → Behavior: **Load lazy content** (off by default) scrolls the page once after it loads — and back to the top — so lazy images and embeds are actually fetched and measured; a banner above the Browser tab shows while this happens. Plus **Disable browser cache** and **Always clean cookies**.

### Improved
- Central data point: one reactive store per page load holding the browser, server and file results (with a generation, so stale results are dropped).
- **Size** tab: download size first (Lighthouse-style total byte weight), cache hits counted, and resources that load late (lazy content, ads after scrolling) included. While "Load lazy content" is off, a note explains that totals may be underestimated because lazy resources were never fetched.
- Keyboard shortcuts (Cmd/Ctrl+L focuses the location bar, Cmd/Ctrl+arrow keys switch tabs) and mouse-wheel tab switching on desktop.
- About screen: the Key Features list matches the app.

### Fixed
- Request Timeline no longer crashes ("Invalid argument(s)") on pages whose last requests start at the very end of the timeline.
- UI jank while loading and rendering pages.
- Startup: ink-splash errors in the URL history list.
- SVG icons missing their viewport.

## 1.2.0

### New
- **Sovereignty** tab: weighted digital sovereignty score — which country the site and its services are hosted in, and who sees your visit.
- **Privacy** tab: which trackers and services see your visit, now also trackers only present in the page source.
- **Size** tab: page weight per asset (images, scripts, stylesheets, …) with file-type filters, thumbnails and service logos.
- **Media** tab: separate multi-column overviews of fonts (including Adobe Fonts) and inline images.
- Logos of detected trackers and services are now shown throughout the app.
- A notice under the analysis tabs that the results are an indication only.

### Improved
- URL history now deduplicates entries like a browser does.
- Settings: cleaner tiles and a compact theme mode picker.
- DOM Tree is hidden for non-HTML files; the file type is detected from the file extension.
- Better detection of structured data (schema.org) in Metadata.
- Android: sharing files from shared storage (/sdcard) now works.

### Fixed
- The Browser tab now only loads when first selected if "Always use Browser" is off.
- iOS: correct asset sizes in the Size tab for images resized via URL parameters.

### Security
- Strict TLS by default; for a deviating certificate you are asked per session whether to trust it.
- Deep links can no longer read local files.
- Several further security fixes (including XSS in the RSS view).
