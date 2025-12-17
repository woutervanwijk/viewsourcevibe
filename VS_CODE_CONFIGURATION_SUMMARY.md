# VS Code Configuration Summary

## Overview
Configured VS Code to always run Flutter on F5 and provide a comprehensive development environment for the Vibe HTML Viewer project.

## Files Created

### 1. `.vscode/launch.json`
**Purpose**: Defines launch configurations for debugging and running the app

**Configurations:**
- **Flutter (Debug)**: Default debug configuration
- **Flutter (Profile)**: Profile mode for performance analysis
- **Flutter (Release)**: Release mode for production testing
- **Flutter (Test)**: Test configuration

**Key Features:**
```json
{
  "name": "Flutter",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "flutterMode": "debug",
  "deviceId": "all"
}
```

### 2. `.vscode/settings.json`
**Purpose**: Project-specific VS Code settings

**Key Settings:**
- **Flutter SDK**: Configured to use project's Flutter SDK
- **Hot Reload**: Enabled on save
- **Hot Restart**: Enabled on save
- **Launch Configuration**: Flutter as default
- **Editor Settings**: Font, size, ligatures, formatting
- **File Exclusions**: Excludes build directories
- **Terminal Settings**: Font and size

### 3. `.vscode/tasks.json`
**Purpose**: Defines build and test tasks

**Tasks:**
- **Flutter: Run**: Default build task (F5)
- **Flutter: Build APK**: Android build
- **Flutter: Build iOS**: iOS build
- **Flutter: Test**: Run tests
- **Flutter: Pub Get**: Dependency management
- **Flutter: Clean**: Clean build

**Key Features:**
```json
{
  "label": "Flutter: Run",
  "type": "shell",
  "command": "flutter run -d all --flavor development",
  "group": {
    "kind": "build",
    "isDefault": true
  }
}
```

## Configuration Details

### Launch Configuration

**F5 Behavior:**
1. Press F5 in VS Code
2. VS Code uses the default launch configuration
3. Flutter app launches in debug mode
4. Hot reload and hot restart work automatically

**Debug Features:**
- Breakpoints work correctly
- Variable inspection available
- Call stack visible
- Debug console shows output

### Task Configuration

**Build Task (Ctrl+Shift+B):**
1. Runs `flutter run -d all --flavor development`
2. Launches app on all available devices
3. Uses development flavor

**Test Task:**
1. Runs `flutter test`
2. Executes all test files
3. Shows test results in output panel

### Editor Configuration

**Formatting:**
- Automatic formatting on save
- Dart-specific formatting rules
- Consistent code style

**Font Settings:**
- Fira Code with ligatures
- Size 14 for editor, 12 for terminal
- Monospace font family

**File Management:**
- Auto-save on focus change
- Excludes build directories from search
- Preview mode disabled for better navigation

## Setup Instructions

### For New Developers

1. **Install VS Code**: Download and install Visual Studio Code
2. **Install Extensions**:
   - Flutter extension
   - Dart extension
   - Fira Code font (optional)
3. **Open Project**: Open the project in VS Code
4. **Select Device**: Choose target device from status bar
5. **Run App**: Press F5 to launch the app

### For Existing Developers

1. **Update Configuration**: The new files will be automatically detected
2. **Verify Settings**: Check that Flutter SDK path is correct
3. **Test Launch**: Press F5 to verify it works
4. **Run Tests**: Use the test task to verify everything

## Troubleshooting

### Common Issues

**Issue: F5 doesn't work**
- Check that Flutter extension is installed
- Verify launch.json exists in .vscode directory
- Ensure default configuration is set

**Issue: Hot reload not working**
- Check `dart.flutterHotReloadOnSave` setting
- Verify no syntax errors in code
- Restart VS Code if needed

**Issue: Device not detected**
- Run `flutter devices` in terminal
- Check USB debugging on Android
- Ensure proper device setup

### Debugging Tips

1. **Check Output Panel**: View Flutter run output
2. **Debug Console**: See debug messages
3. **Log Files**: Check debug.log, test.log, daemon.log
4. **Flutter Doctor**: Run `flutter doctor` for setup issues

## Best Practices

### Development Workflow

1. **Write Code**: Implement features in editor
2. **Save File**: Automatic formatting applied
3. **Hot Reload**: Changes appear instantly (Ctrl+S)
4. **Hot Restart**: Full app restart if needed
5. **Debug**: Set breakpoints and inspect variables

### Testing Workflow

1. **Write Tests**: Create test files in test directory
2. **Run Tests**: Use test task or `flutter test`
3. **View Results**: Check output panel for results
4. **Debug Tests**: Set breakpoints in test code

### Build Workflow

1. **Development Build**: F5 for quick testing
2. **Profile Build**: Analyze performance
3. **Release Build**: Prepare for production
4. **Clean Build**: Remove build artifacts

## Advanced Configuration

### Custom Flavors
To add more flavors, update launch.json:
```json
{
  "name": "Flutter (Staging)",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "args": ["--flavor", "staging"],
  "flutterMode": "debug"
}
```

### Custom Devices
To target specific devices:
```json
{
  "name": "Flutter (Android)",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "deviceId": "SM_G975F" // Specific device ID
}
```

### Custom Arguments
To add custom arguments:
```json
{
  "name": "Flutter (Custom)",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "args": ["--flavor", "development", "--dart-define", "API_URL=https://api.example.com"]
}
```

## Summary

The VS Code configuration provides:

1. **Seamless Development**: F5 always runs Flutter
2. **Comprehensive Tooling**: Debug, test, build tasks
3. **Consistent Formatting**: Automatic code styling
4. **Efficient Workflow**: Hot reload and restart
5. **Project-Specific Settings**: Optimized for this project

Developers can now enjoy a fully configured VS Code environment that maximizes productivity and provides a consistent development experience across the team.