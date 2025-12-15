# HTML Viewer App - Flutter Implementation

## Overview
A cross-platform HTML source viewer app for iOS and Android built with Flutter. The app provides syntax highlighting, file browsing, text search, and supports multiple web file formats.

## Features Implemented

### ✅ Core Functionality
- **Cross-platform support**: Works on both iOS and Android
- **File browsing**: Open HTML, CSS, JS, JSON, XML, and text files
- **Syntax highlighting**: Beautiful code highlighting for multiple languages
- **Text search**: Find text within files with navigation
- **Line numbers**: Display line numbers for easy navigation
- **File information**: Shows file size, line count, and format

### ✅ Supported File Formats
- HTML (.html, .htm)
- CSS (.css)
- JavaScript (.js)
- JSON (.json)
- XML (.xml)
- Text (.txt)
- **Web URLs** (http://, https://)

### ✅ User Interface
- **Clean Material Design**: Modern, intuitive interface
- **Toolbar**: Quick access to file operations
- **Search bar**: Real-time text search with navigation
- **File viewer**: Syntax-highlighted content with line numbers
- **Sample files**: Built-in examples for testing
- **URL loading**: Fetch and view HTML from any website

## Project Structure

```
htmlviewer/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── models/
│   │   └── html_file.dart          # File model
│   ├── screens/
│   │   └── home_screen.dart        # Main screen
│   ├── services/
│   │   └── html_service.dart       # Core business logic
│   ├── utils/
│   │   └── file_utils.dart         # File utilities
│   └── widgets/
│       ├── file_viewer.dart        # File content viewer
│       ├── search_bar.dart         # Search functionality
│       └── toolbar.dart            # App toolbar
├── assets/
│   ├── sample.html                # Sample HTML file
│   └── sample.css                 # Sample CSS file
├── pubspec.yaml                   # Dependencies
└── PROJECT_SUMMARY.md             # This file
```

## Key Dependencies

- **flutter_highlight**: Syntax highlighting for code
- **highlight**: Language definitions for syntax highlighting
- **file_picker**: File browsing functionality
- **http**: HTTP requests for URL loading
- **provider**: State management
- **path_provider**: File system access

## How to Use

### Opening Files
1. **From Device**: Tap the folder icon to browse and select a file
2. **Sample Files**: Tap the code icon to load built-in examples
3. **From URL**: Tap the globe icon to enter any website URL
4. The file content will be displayed with syntax highlighting

### Searching
1. Type in the search bar to find text
2. Use the arrow buttons to navigate between results
3. See the current result count (e.g., "1/5")

### Navigation
- Scroll through the file content
- Line numbers help with orientation
- File info shows line count and size

## Technical Highlights

### Syntax Highlighting
- Uses the GitHub theme for familiar colors
- Supports multiple languages automatically
- Fast rendering even for large files

### URL Loading
- Automatic HTTP/HTTPS detection
- URL validation and error handling
- Loading indicators during fetch
- Displays source URL in file info

### Search Implementation
- Real-time search as you type
- Case-insensitive matching
- Navigation through results
- Visual highlighting of matches

### Performance Considerations
- Efficient text rendering with flutter_highlight
- Line numbers generated on-demand
- Search results cached for quick navigation

## Next Steps (Future Enhancements)

- **Settings screen**: Theme selection, font size, etc.
- **Recent files**: History of opened files
- **File editing**: Basic text editing capabilities
- **Multiple tabs**: Open several files at once
- **Dark mode**: Theme switching
- **Export functionality**: Save modified files
- **Advanced search**: Regular expressions, case sensitivity

## Running the App

1. Make sure you have Flutter installed
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app
4. Test on both iOS and Android emulators/devices

## Testing

The app includes sample files for testing:
- `sample.html`: Comprehensive HTML example
- `sample.css`: CSS styling example

You can also test by:
1. Creating your own HTML/CSS/JS files
2. Using the file picker to open them
3. Testing search functionality with different queries

## Build & Deployment

To build for production:
```bash
# Android
flutter build apk
flutter build appbundle

# iOS
flutter build ios
```

## Conclusion

This Flutter app provides a solid foundation for an HTML source viewer with all the essential features. The architecture is clean and modular, making it easy to extend with additional functionality. The cross-platform nature of Flutter ensures that the app works seamlessly on both iOS and Android with a single codebase.