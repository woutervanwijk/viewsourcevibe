# View Source Vibe
*Pocket web inspector*

A HTML/JS/CSSView Source & Page Inspector. I wanted to create an app like this for some time, since most View Source apps on mobile were annoying or old. It had to be: 
- free (open source)
- open files and urls
- options to share to and from the app
- easy to use
- syntax highlighting
- wordwrap
- line numbers
- theme support
- well tested on usability

| iOS | Android |
|-----|---------|
| ![iOS Mobile](assets/vibe%20screens/ios/Simulator%20Screenshot%20-%20iPhone%208%20Plus%20-%202026-02-18%20at%2016.46.49.png) | ![Android Tablet](assets/vibe%20screens/android/pixel%20tablet/Screenshot_1771434114.png) |


So I took the chance to experiment with Vibe coding (literally with Mistral Vibe). Vibe coding really suits me, because I mostly want the results of a good app, not the coding itself. I used Flutter because I know it already (we coded the Fiper.net app in it). I began with a simple View Source app, and gradually added more and more features, using Vibe and later also Gemini, Opus to help me with the implementation.

- Coded myself the minumum possible
- Kept the prompts broad, by purpose. To see how good it is. (It's good! in a lot of ways)
- Logs/prompts in the repo
- Tested a lot to make sure it really works well

Get it on the Play Store: 
https://play.google.com/store/apps/details?id=info.wouter.sourceviewer

Or the App Store:
https://apps.apple.com/us/app/view-source-vibe/id6759335719

===

# This is what Vibe wrote itself: 

**Cross-Platform Source Code Viewer & Page analyzer**

View Source Vibe is a powerful tool to view source code, browse and inspect web pages, and analyze web technologies. Built with Flutter, it offers a desktop-class inspection experience on your mobile device.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-blue)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-green)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

## ✨ key features

- **📱 View Source & Inspect**
  - View HTML, CSS, JS, XML, and JSON with syntax highlighting.
  - **DOM Tree Inspector:** Navigate the document structure like a pro.
  - **Reader Mode:** Distraction-free reading for articles.
  - **RSS/Atom Feed Support:** Auto-detects and displays feeds cleanly.

- **🔍 Deep Analysis**
  - **Metadata:** See all meta tags, social share previews (OpenGraph, Twitter Cards).
  - **Tech Stack Detection:** Identifies CMS, frameworks, and libraries used on a page.
  - **Network Probe:** Inspect HTTP headers, cookies, and security details.
  - **Asset Browser:** List and view all images, scripts, and stylesheets linked in the page.

- **🛠️ Power Tools**
  - **Browser Integration:** "Surf & View Source" browser with tab support.
  - **Bundles:** Save and organize your favorite sites and snippets.
  - **Share Action:** Open any URL or text directly from other apps.

> [!NOTE]
> **Disclaimer:** The detection of services, tech stacks, and cookies is currently in beta and may not be 100% reliable yet.

## 🎯 Usage

1. **Enter a URL** or pick a local file to start.
2. **Browse** the web comfortably in the built-in browser.
3. **Switch Tabs** to inspect Source, DOM, Metadata, or Network details.
4. **Share** content from other apps to "View Source Vibe" for instant analysis.

## 🖥️ Installing the macOS App

The macOS build is not notarized, so Gatekeeper will block it on first launch. To open it anyway:

**Option 1 — Right-click method (easiest)**
1. Right-click (or Control-click) `View Source Vibe.app`
2. Choose **Open** from the context menu
3. Click **Open** in the dialog that appears

**Option 2 — System Settings**
1. Try to open the app normally — it will be blocked
2. Go to **System Settings → Privacy & Security**
3. Scroll down and click **Open Anyway** next to the blocked app

**Option 3 — Terminal (removes the quarantine flag permanently)**
```bash
xattr -cr "/Applications/View Source Vibe.app"
```

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

*View Source Vibe - Your pocket web inspector.* 🚀