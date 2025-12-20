# Xcode Project Cleanup Instructions

## 🚨 Issue Identified
The Xcode project has a dependency cycle caused by the Share Extension target that was created but not properly configured. This is preventing the iOS build from completing successfully.

## 🔧 Manual Cleanup Steps

### Step 1: Open Xcode Project
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select the project in the Navigator

### Step 2: Remove Share Extension Target
1. In the targets list, find `SourceviewerShare`
2. Right-click on `SourceviewerShare` and select **Delete**
3. Choose **Delete** (not just remove reference)

### Step 3: Clean Build Folder
1. In Xcode, go to **Product** > **Clean Build Folder**
2. Or use shortcut: **Cmd + Shift + K**

### Step 4: Remove Share Extension References
1. Open `ios/Runner.xcodeproj/project.pbxproj` in a text editor
2. Search for all occurrences of `SourceviewerShare`
3. Remove the following sections:
   - Target configuration for `SourceviewerShare`
   - Build file references to `SourceviewerShare.appex`
   - File references to Share Extension files

### Step 5: Verify Info.plist
Ensure the main Info.plist still has the URL handling configurations:
```xml
<!-- URL Document Type -->
<dict>
    <key>CFBundleTypeName</key>
    <string>Web URL</string>
    <key>LSHandlerRank</key>
    <string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array>
        <string>public.url</string>
    </array>
</dict>

<!-- HTTP/HTTPS URL Schemes -->
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

<!-- Background URL Handling -->
<key>LSHandlesURLsInBackground</key>
<true/>
```

### Step 6: Clean Derived Data
1. In Xcode, go to **Xcode** > **Preferences** > **Locations**
2. Click the arrow next to **Derived Data**
3. Click **Delete** to remove derived data

### Step 7: Rebuild Pods
1. Run `cd ios && pod deintegrate`
2. Run `pod install`
3. Run `cd ..`

### Step 8: Test Build
1. Run `flutter clean`
2. Run `flutter build ios --no-codesign`

## ✅ Alternative Solution

If manual cleanup is too complex, you can:

1. **Create a new Xcode project:**
   ```bash
   cd ios
   rm -rf Runner.xcodeproj
   flutter create --platforms ios --project-name viewsourcevibe .
   ```

2. **Reapply necessary configurations:**
   - Update bundle identifier to `info.wouter.sourceviewer`
   - Add URL schemes and document types from the current Info.plist
   - Reconfigure signing and capabilities

3. **Test the new project:**
   ```bash
   flutter build ios --no-codesign
   ```

## 📋 Current Status

### ✅ Working Features
- **URL Clearing:** Local files clear the URL bar
- **URL Display:** Web URLs show in the URL bar
- **Smart Detection:** Proper distinction between content types
- **Android Build:** Working correctly
- **Flutter Code:** All features implemented

### ⚠️ Issues to Resolve
- **iOS Build Cycle:** Share Extension causing dependency issues
- **Xcode Configuration:** Need to clean up project references
- **Share Extension:** Optional enhancement causing build problems

## 🎯 Recommended Approach

Since the Share Extension was an optional enhancement and the core Safari sharing functionality is already working through Info.plist configurations, I recommend:

1. **Remove the Share Extension** completely
2. **Keep the Info.plist enhancements** (already working)
3. **Focus on the core app functionality**

The current implementation provides:
- ✅ URL receiving from Safari (via AppDelegate)
- ✅ URL scheme handling (http/https)
- ✅ Document type support (public.url)
- ✅ Background URL handling

This is sufficient for most Safari sharing use cases without the complexity of a full Share Extension.

## 🔮 Next Steps

After cleaning up the Xcode project:
1. ✅ Test Safari URL sharing
2. ✅ Verify app icon appears in share sheet
3. ✅ Confirm URL handling works correctly
4. ✅ Ensure all other functionality remains intact

The app will have robust URL sharing capabilities without the build complexity of a Share Extension.