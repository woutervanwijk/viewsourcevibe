# View Source Vibe - AI Agent Instructions

This file contains the context, architecture guidelines, and coding standards for AI assistants (like Cursor, GitHub Copilot, or Antigravity) working on the **View Source Vibe** project.

## 📌 Project Overview
**View Source Vibe** is a cross-platform (iOS, Android, macOS, Windows, Linux) Flutter application used to inspect web pages, view source code (HTML, CSS, JS, XML, JSON), analyze DOM trees, and extract tech stacks/metadata from URLs or local files. It heavily relies on in-app browsers, DOM parsing, and deep linking for seamless sharing capabilities.

## 🛠 Tech Stack
- **Framework:** Flutter (SDK `>=3.3.0 <4.0.0`)
- **State Management:** `provider`
- **Core Packages:** 
  - `flutter_inappwebview` (Browser, network interception, WebView handling)
  - `re_editor` & `re_highlight` (Code viewing & syntax highlighting)
  - `html` & `xml` (DOM tree parsing)
  - `flutter_fancy_tree_view2` (DOM UI representation)
  - `shared_preferences` (Persistent local settings)
  - `app_links` (Deep linking)

## 🏗 Architecture & Directory Structure
The `lib/` directory follows a clean separation of concerns:
- **`models/`**: Data classes and state representations. Keep them immutable where possible.
- **`screens/`**: Full-page UI files (e.g., `BrowserScreen`, `SourceViewerScreen`).
- **`widgets/`**: Reusable UI components (e.g., custom buttons, dialogs, bottom sheets).
- **`services/`**: Core business logic, network requests, DOM parsing logic, and file handling.
- **`utils/`**: Helper functions, formatters, extensions, and constants.
- **`ui/`**: App-wide UI constants, theming, design tokens (colors, typography).

## 💡 AI Coding Guidelines

1. **Keep it Simple & Pragmatic ("Vibe Coding")**
   - The original author prioritizes getting results and working software over overly strict academic purity. Keep code clean, readable, and functional. Avoid premature optimization or unnecessary over-engineering.
   - Write self-documenting code with clear variable and function names.

2. **State Management (`provider`)**
   - Use `Consumer` or `context.read<T>()` / `context.watch<T>()`.
   - Keep business logic strictly outside of the UI components. State mutations should happen inside `ChangeNotifier` classes in the `services/` or `models/` folders.

3. **UI / UX**
   - Follow Material/Cupertino design guidelines depending on the platform where applicable.
   - The app must handle varied screen sizes (mobile phones, tablets, and desktop windows). Ensure responsiveness using `Expanded`, `Flexible`, `LayoutBuilder`, or standard constraints.

4. **Web Technologies & Parsing**
   - Be cautious when making changes to `flutter_inappwebview` logic. Modifying WebView settings, injected scripts, or cache configurations can easily break features on specific platforms.
   - Ensure DOM/HTML parsing handles malformed HTML gracefully without crashing the app.

5. **Error Handling & Logs**
   - Catch exceptions when reading files, parsing documents, or making HTTP requests. Show user-friendly error messages (e.g., via SnackBar or Error UI layer) instead of failing silently.
   - Do not leave raw `print()` statements in production code unless they are temporary for debugging.

6. **Testing**
   - Ensure unit tests (in `test/`) are maintained or added when writing complex utility functions, parsers, or sharing logic (e.g., `test_sharing_logic.dart`).

## 🔄 AI Assistant Workflow
- Before implementing a feature, carefully read the related `pubspec.yaml` dependencies and check how similar features are implemented across the `screens/` or `services/`.
- If a user requests a bug fix related to the browser or tab bar (e.g., `flutter_inappwebview` caching, or `TabController` synchronization), deeply analyze the widget lifecycle (`initState`, `dispose`) to ensure no memory leaks occur.
- When generating changes, prefer small, focused file edits over rewriting entire massive files.

---
*End of AI instructions. Use this context to inform all future code completion and generation.*
