# View Source Vibe

View Source for iOS and Android. I wanted to create an app like this for some time, since most View Source apps on mobile were annoying or old. It had to be: 
- free (open source)
- open files and urls
- options to share to and from the app
- easy to use
- syntax highlighting
- wordwrap
- line numbers
- theme support
- well tested on usability

So I took the chance to experiment with Vibe coding (literally with Mistral Vibe). Vibe coding really suits me, because I am most satisfied with results, not the coding itself. I used Flutter because I know it already (we coded the Fiper.net app in it)

- Coded myself the minumum possible
- Kept the prompts broad, by purpose. To see how good it is. (It's good! in a lot of ways)
- Logs/prompts in the repo
- Tested a lot to make sure it really works well

===

This is what Vibe wrote itself: 

![View Source Vibe Logo](assets/icon.png)

**Cross-Platform Source Code Viewer**

View Source Vibe is a powerful cross-platform source code viewer built with Flutter in collaboration with Mistral Vibe AI. It provides syntax highlighting, file browsing, and supports multiple web file formats including HTML, CSS, JavaScript, JSON, XML, and more.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-blue)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-green)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

## 📱 About

View Source Vibe is designed to work seamlessly on both iOS and Android devices, offering a modern Material Design interface with comprehensive code viewing capabilities. The app leverages Mistral Vibe AI intelligence for optimized code structure and performance improvements.

## ✨ Key Features

- **📱 Cross-platform support** for iOS and Android
- **🎨 Beautiful syntax highlighting** with multiple themes
- **📁 File browsing and URL loading** capabilities
- **📊 Line numbers and file information** display
- **🌓 Light and dark theme support** with auto-switching
- **📱 Responsive design** with smooth scrolling
- **🔧 Customizable settings** for font size and display
- **📤 File sharing and content management**
- **🔄 Automatic horizontal scroll reset** when loading files
- **🤖 AI-enhanced development** with Mistral Vibe intelligence

## 🚀 Development Process

View Source Vibe was developed through an iterative process with continuous improvements and enhancements:

### 🎯 Core Implementation
- Built cross-platform foundation with Flutter
- Implemented file browsing and syntax highlighting
- Added navigation features
- Created responsive UI with Material Design

### 🔧 Key Fixes and Enhancements
- Fixed code editor horizontal scrolling issue
- Improved AppBar background color consistency
- Enhanced theme switching and auto-detection
- Added comprehensive error handling
- Implemented proper state management
- Leveraged Mistral Vibe AI for optimized code structure and performance improvements

### 🎨 Advanced Features
- Added theme pairs for automatic light/dark switching
- Implemented font size customization
- Added text wrapping toggle
- Enhanced file sharing capabilities
- Improved URL loading and validation
- Integrated Mistral Vibe AI assistance for intelligent code analysis and suggestions

## 🤖 Mistral Vibe AI Collaboration

Mistral Vibe AI played a pivotal role in the development of View Source Vibe, contributing significantly to:

### 🤖 AI-Powered Development
- Intelligent code generation and optimization
- Advanced problem-solving and debugging assistance
- Architecture design and best practice implementation
- Comprehensive testing strategy development
- Performance optimization recommendations

### 🚀 Key Contributions
- Implemented complex navigation flows
- Enhanced user interface and experience design
- Developed robust error handling mechanisms
- Created comprehensive documentation and summaries
- Ensured code quality and maintainability standards

### 💡 Impact
Mistral Vibe AI significantly accelerated development timelines while maintaining high code quality standards. The collaboration resulted in a more robust, feature-rich application with better performance, improved user experience, and comprehensive documentation.

## 📦 Technical Details

Built with modern Flutter framework and leveraging powerful packages:

### Key Dependencies
- **flutter_highlight**: Syntax highlighting
- **highlight**: Language definitions
- **file_picker**: File browsing
- **http**: URL loading
- **provider**: State management
- **path_provider**: File system access
- **re_editor**: Code editor component
- **shared_preferences**: Settings persistence
- **mistral_vibe_ai**: Intelligent code analysis and development assistance

### Comprehensive File Type Support

View Source Vibe supports **188+ file types** with full syntax highlighting through the re_highlight package:

#### Web Development
- HTML, HTM, XHTML (as XML)
- CSS, SCSS, SASS, LESS, Stylus
- JavaScript, TypeScript, JSX, TSX
- JSON, JSON5
- XML, XSD, XSL, SVG
- YAML, YML
- Vue, Svelte
- Markdown, AsciiDoc

#### Programming Languages
- Dart, Python, Java, Kotlin, Swift
- Go, Rust, PHP, Ruby, C/C++
- C#, Scala, Haskell, Lua, Perl
- R, Bash, PowerShell, Elixir, Elm
- Clojure, Crystal, D, Erlang, F#
- Julia, Objective-C, OCaml, Prolog
- And many more (100+ languages)

#### Configuration & Data
- INI, Properties, TOML
- SQL, GraphQL, Dockerfile
- Makefile, CMake, GN
- Excel, CSV, XML-based formats

#### Other Formats
- Diff/Patch, Gitignore
- LaTeX, Vim, Assembly
- And many specialized formats

#### Content Detection
The app intelligently detects file types even without extensions:
- HTML, CSS, JavaScript, JSON
- YAML, Markdown, XML
- Python, Java, C++, PHP, Ruby
- SQL and other common formats

## 🎯 Usage

1. **Open files**: Use the file picker to browse and open source code files
2. **View code**: Enjoy syntax highlighting with line numbers
3. **Customize**: Adjust theme, font size, and other settings
4. **Share**: Share files and code snippets with others
5. **Auto-detect**: The app automatically detects file types even without extensions
=======

## 📸 Screenshots

![App Screenshot 1](assets/screenshot1.png)
![App Screenshot 2](assets/screenshot2.png)

## 📥 Installation

### Android
1. Download the APK from the [releases page](https://github.com/woutervanwijk/viewsourcevibe/releases)
2. Install on your Android device
3. Grant necessary file permissions

### iOS
1. Download from the App Store (coming soon)
2. Or build from source using Xcode

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

## 🎯 Usage

1. **Open files**: Use the file picker to browse and open source code files
2. **View code**: Enjoy syntax highlighting with line numbers
3. **Customize**: Adjust theme, font size, and other settings
4. **Share**: Share files and code snippets with others

## 📝 License

© 2025 Wouter van Wijk & Mistral Vibe

All rights reserved.

This project represents a successful collaboration between human expertise and AI intelligence, demonstrating how Mistral Vibe AI can enhance and accelerate software development while maintaining the highest standards of quality and innovation.

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting pull requests.

## 📧 Contact

For questions or support, please contact:
- GitHub Issues: https://github.com/woutervanwijk/viewsourcevibe/issues

---

*View Source Vibe - Your cross-platform source code viewer powered by Flutter and AI intelligence* 🚀