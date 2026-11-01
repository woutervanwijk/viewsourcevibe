# View Source Vibe - AI Agent Instructions

Context, architecture and coding standards for AI assistants working on **View Source Vibe**.

## Project Overview
Cross-platform (iOS, Android, macOS, Windows, Linux) Flutter app to inspect web pages and view source (HTML, CSS, JS, XML, JSON), analyze DOM trees, and extract tech stacks/metadata from URLs or local files. Relies on in-app browsers, DOM parsing, and deep linking.

## Tech Stack
- Flutter (SDK `>=3.3.0 <4.0.0`), state management via `provider`
- `flutter_inappwebview` (browser, network interception), `re_editor`/`re_highlight` (code viewing), `html`/`xml` (DOM parsing), `flutter_fancy_tree_view2` (DOM UI), `shared_preferences` (settings), `app_links` (deep linking)

## Build, Release & Signing
- Desktop releases: `.github/workflows/build-desktop.yml`. A `v*` tag builds macOS + Windows artifacts and creates a GitHub Release.
- macOS artifact = DMG from `flutter build macos --release`, then signed, notarized, stapled, uploaded. Do **not** add `--codesign` (unsupported in the pinned CI toolchain).
- Signing uses a **Developer ID Application** certificate in the `APPLE_*_P12` secret; App Store certificates don't work for the DMG flow. Required secrets: `APPLE_*_P12`, `APPLE_*_PASSWORD`, `APPLE_ID`, `APPLE_PASSWORD`, `APPLE_TEAM_ID`.
- CI patches `DEVELOPMENT_TEAM` from `APPLE_TEAM_ID`; don't hard-code a team in workflow scripts. Keep `macos/Runner/Release.entitlements` aligned with app capabilities (used when re-signing the bundle).

## Architecture (`lib/`)
- `models/` immutable data classes/state · `screens/` full pages (`BrowserScreen`, `SourceViewerScreen`) · `widgets/` reusable UI · `services/` business logic, network, DOM parsing, files · `utils/` helpers/formatters/constants · `ui/` theming/design tokens

## Coding Guidelines
1. **Keep it simple ("vibe coding")**: working software over academic purity; no premature optimization. Self-documenting names.
2. **State (`provider`)**: use `Consumer` / `context.read` / `context.watch`; mutations only in `ChangeNotifier`s in `services/` or `models/`, never in UI.
3. **UI/UX**: Material/Cupertino per platform; responsive for phones, tablets, desktop (`Expanded`, `Flexible`, `LayoutBuilder`, constraints).
4. **WebView & parsing**: be careful with `flutter_inappwebview` settings/injected scripts/cache — easily breaks per-platform features. DOM/HTML parsing must handle malformed HTML gracefully.
5. **Errors & logs**: catch exceptions on file/parse/HTTP; show user-friendly errors (SnackBar/error UI). No raw `print()` in production code.
6. **Tests**: add/maintain unit tests in `test/` for complex utilities, parsers, sharing logic (e.g. `test_sharing_logic.dart`).

## Workflow
- Before implementing: read `pubspec.yaml` and how similar features are built in `screens/`/`services/`.
- Browser/tab-bar bugs (WebView caching, `TabController` sync): analyze widget lifecycle (`initState`, `dispose`) for memory leaks.
- Prefer small, focused edits over rewriting large files.
