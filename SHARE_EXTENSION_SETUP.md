# Share Extension Setup Guide for View Source Vibe

## Overview

This guide provides instructions for setting up the Share Extension in Xcode to enable URL and file sharing to View Source Vibe from other iOS apps.

## Files Created

The following files have been created for the Share Extension:

1. **`ios/SourceviewerShare/Info.plist`** - Share Extension configuration
2. **`ios/SourceviewerShare/ShareViewController.swift`** - Share Extension view controller
3. **`ios/SourceviewerShare/Base.lproj/MainInterface.storyboard`** - Share Extension UI

## Xcode Project Setup

### Step 1: Add Share Extension Target

1. Open the Xcode project (`ios/Runner.xcworkspace`)
2. Go to **File > New > Target**
3. Select **Share Extension** under iOS > Application Extension
4. Click **Next**
5. Enter product name: `SourceviewerShare`
6. Make sure the language is set to **Swift**
7. Click **Finish**

### Step 2: Configure Share Extension Target

1. Select the **SourceviewerShare** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Set up proper signing (same as main app)
4. Go to **Info** tab and verify the Info.plist matches our created file

### Step 3: Add Files to Target

1. Delete the auto-generated files from the Share Extension
2. Add our created files to the Share Extension target:
   - `Info.plist`
   - `ShareViewController.swift`
   - `Base.lproj/MainInterface.storyboard`
3. Make sure files are properly assigned to the Share Extension target

### Step 4: Configure App Groups (Optional)

For communication between main app and extension:

1. Go to **Signing & Capabilities** for both main app and extension
2. Add **App Groups** capability
3. Create a new app group: `group.info.wouter.sourceviewer`
4. Add this group to both targets

### Step 5: Update Main App Info.plist

The main app's Info.plist has been enhanced with:

```xml
<!-- URL Scheme for deep linking -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>info.wouter.sourceviewer</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>viewsourcevibe</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>Web URL Handler</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>http</string>
            <string>https</string>
        </array>
    </dict>
</array>

<!-- Document types for file sharing -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Web URL</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.url</string>
        </array>
    </dict>
    <!-- Other document types... -->
</array>
```

### Step 6: Test the Share Extension

1. Build and run the main app
2. Open Safari and navigate to a webpage
3. Tap the share button
4. View Source Vibe should appear in the share sheet
5. Select the app and verify the URL is shared correctly

## Share Extension Activation Rule

The Share Extension is configured to activate for:

- **URLs**: `public.url` - Web URLs
- **HTML Files**: `public.html` - HTML content  
- **Text Files**: `public.plain-text`, `public.text` - Plain text
- **CSS Files**: `public.css` - CSS content
- **JavaScript Files**: `public.javascript` - JavaScript content

## Troubleshooting

### App doesn't appear in share sheet

1. Verify Share Extension target is properly configured
2. Check that Info.plist has correct activation rules
3. Ensure app is built with the Share Extension included
4. Try restarting the device after installation
5. Check that document types match what you're sharing

### Share Extension crashes

1. Check console logs for error messages
2. Verify all files are properly added to the target
3. Ensure proper signing and capabilities
4. Check that storyboard is properly connected to view controller

### Content not processed correctly

1. Verify `processSharedContent()` method in ShareViewController
2. Check that content types match expected types
3. Ensure proper error handling in content processing

## Supported Content Types

The Share Extension supports:

- **URLs**: Web addresses from Safari and other browsers
- **HTML Files**: HTML content and web pages
- **Text Files**: Plain text and rich text content
- **CSS Files**: Cascading Style Sheets
- **JavaScript Files**: JavaScript code files

## Communication with Main App

The Share Extension communicates with the main app using:

1. **Method Channels**: Flutter method channel for real-time communication
2. **App Groups**: Shared container for persistent data (optional)
3. **URL Schemes**: Custom URL schemes for deep linking

## Main App Integration

The main app has been enhanced to:

1. Handle shared content when app is launched
2. Process real-time shared content via method channels
3. Support various content types (URLs, files, text)
4. Provide proper error handling and user feedback

## Additional Enhancements

For better URL sharing support, consider:

1. **Universal Links**: Set up universal links for better web integration
2. **Siri Shortcuts**: Add Siri shortcuts for quick sharing
3. **Spotlight Indexing**: Enable content indexing for better search
4. **Handoff Support**: Add handoff between devices

## References

- [Apple Share Extension Documentation](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- [Flutter Method Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [iOS App Extension Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)

## Support

For issues with Share Extension setup:

1. Check Xcode project configuration
2. Verify all files are properly included
3. Ensure proper code signing
4. Test on physical device (simulator may have limitations)
5. Check console logs for detailed error information

The Share Extension provides a seamless way for users to share web content directly to View Source Vibe from Safari and other apps.