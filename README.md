# View Source Vibe
*Pocket web page explorer*

Viewing the source of a webpage is sooooo early 2026!! Just use View Source Vibe to easily see what's in the page, without looking at the source. Of course we included a source code viewer and a DOM Tree, but you probably don't need them for most quick glances, because of our easy to use exploring tools.

| iOS | Android |
|-----|---------|
| ![iOS Mobile](assets/vibe%20screens/ios/Simulator%20Screenshot%20-%20iPhone%208%20Plus%20-%202026-02-18%20at%2016.46.49.png) | ![Android Tablet](assets/vibe%20screens/android/pixel%20tablet/Screenshot_1771434114.png) |


This started as an experiment with Vibe coding (literally with Mistral Vibe). Vibe coding really suits me, because I mostly want the results of a good app, not the coding itself. I used Flutter because I know it already (we coded the Fiper.net app in it). I began with a simple View Source app, and gradually added more and more features, using Vibe and later also Gemini, Claude to help me with the implementation.

- Coded myself the minumum possible
- Kept the prompts broad, by purpose. To see how good it is. (It's good! in a lot of ways)
- Logs/prompts in the repo
- Tested a lot to make sure it really works well

Get it on the Play Store: 
https://play.google.com/store/apps/details?id=info.wouter.sourceviewer

Or the App Store:
https://apps.apple.com/us/app/view-source-vibe/id6759335719

Or download a macOS or Windows build from [GitHub Releases](https://github.com/woutervanwijk/viewsourcevibe/releases).

===

# This is what Vibe wrote itself: 

**Web Page Explorer — source, tech stack, trackers and hosting, on any device**

View Source Vibe lets you explore any web page or local file: read its source, walk its DOM, and see what it's built with, who it talks to and where it's hosted. Built with Flutter, it brings a desktop-class inspection experience to your phone, tablet and desktop.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-blue)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows-green)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

## ✨ Key features

Each page opens into a set of tabs:

- **📱 Read**
  - **Source:** HTML, CSS, JS, XML and JSON with syntax highlighting, search, word wrap and line numbers.
  - **DOM Tree:** Navigate the document structure.
  - **Browser:** Built-in browser with tabs ("Surf & View Source"), plus Reader Mode and RSS/Atom feed support.

- **🔍 Understand**
  - **Metadata:** Meta tags and social share previews (OpenGraph, Twitter Cards).
  - **Services:** Detected CMS, frameworks, libraries and third-party services, with the evidence behind each detection (jumps to the source line).
  - **Media:** Images, videos and fonts (including Adobe Fonts) used by the page.

- **🛡️ Privacy & Sovereignty**
  - **Privacy:** Which trackers and other services see your visit.
  - **Sovereignty:** Where the page and its services are hosted and under which country's law they fall.
  - **Cookies:** Cookies set by the page.

> **Note on HTTP:** the app can open plain `http://` sites on purpose (inspecting non-HTTPS sources is core functionality). HTTPS connections are always strictly TLS-validated; an invalid certificate requires an explicit per-session confirmation from you. See [PRIVACY.md](PRIVACY.md).

- **📡 Network**
  - **Timeline:** The request timeline of the page load.
  - **Probe & Headers:** HTTP details and response headers.
  - **Security:** Security headers and TLS details.

- **🛠️ Everything else**
  - **Bundles:** Save and organize favorite sites and snippets.
  - **Share:** Open any URL, file or text from other apps.
  - **Free, open source, no account, no analytics.**

> [!NOTE]
> **Indication only:** Detection of services, tech stacks, trackers, cookies and hosting is based on heuristics and may be incomplete or wrong.

## 🎯 Usage

1. **Enter a URL** or pick a local file to start.
2. **Browse** the web comfortably in the built-in browser.
3. **Switch Tabs** to explore Source, DOM, Services, Privacy, Sovereignty, Media or Network details.
4. **Share** content from other apps to "View Source Vibe" for instant analysis.

## 🖥️ Desktop Releases

Tagged releases build desktop artifacts through GitHub Actions:

- **macOS:** signed, notarized, and stapled DMG for distribution outside the Mac App Store.
- **Windows:** installer built from the Flutter Windows release output.

To create a release build, push a version tag:

```bash
git tag v1.1.4
git push origin v1.1.4
```

The macOS notarization workflow requires these GitHub Actions secrets:

- `APPLE_CERTIFICATE_P12` - base64-encoded Developer ID Application `.p12`
- `APPLE_CERTIFICATE_PASSWORD` - password for the `.p12`
- `APPLE_ID` - Apple ID used for notarization
- `APPLE_PASSWORD` - app-specific password for that Apple ID
- `APPLE_TEAM_ID` - Apple Developer Team ID

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/woutervanwijk/viewsourcevibe.git
cd viewsourcevibe

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📝 License

© 2025 Wouter van Wijk & Mistral Vibe & Gemini & Claude

Released under the MIT License.

*View Source Vibe - Your pocket web page explorer.* 🚀
