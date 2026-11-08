# Changelog

All notable, user-facing changes to View Source Vibe are documented here.

## 1.2.1
- Central data point
- Small bugfixes

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
