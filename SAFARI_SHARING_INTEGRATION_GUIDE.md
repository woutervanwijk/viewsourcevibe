# Safari Sharing Integration Guide

## 🎯 Objective
Enable the app icon to appear in Safari's share sheet when sharing URLs, allowing users to directly share web content to the Htmlviewer app.

## ✅ Completed Configuration Changes

### 1. Info.plist Updates
**File:** `ios/Runner/Info.plist`

#### Added URL Document Type
```xml
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
```

#### Added HTTP/HTTPS URL Schemes
```xml
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
```

#### Added Background URL Handling
```xml
<key>LSHandlesURLsInBackground</key>
<true/>
```

## 🔧 Required Manual Steps (Xcode Setup)

### 2. Create Share Extension Target

#### Step 1: Open Xcode Project
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select the project in the Navigator

#### Step 2: Add Share Extension Target
1. Click the **+** button at the bottom of the targets list
2. Select **iOS** > **Share Extension**
3. Click **Next**

#### Step 3: Configure Share Extension
1. **Product Name:** `HtmlviewerShare`
2. **Language:** Swift
3. **Embed in Application:** Htmlviewer (main app target)
4. Click **Finish**

### 3. Configure Share Extension Settings

#### Step 1: Update Share Extension Info.plist
1. Open `HtmlviewerShare/Info.plist`
2. Replace with the provided `ios/ShareExtension/Info.plist` content
3. Ensure the following keys are present:
   ```xml
   <key>NSExtensionActivationRule</key>
   <dict>
       <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
       <integer>1</integer>
       <key>NSExtensionActivationSupportsWebPageWithMaxCount</key>
       <integer>1</integer>
       <key>NSExtensionActivationSupportsText</key>
       <true/>
       <key>NSExtensionActivationSupportsFileWithMaxCount</key>
       <integer>1</integer>
   </dict>
   ```

#### Step 2: Update Share Extension View Controller
1. Replace `ShareViewController.swift` with the provided file
2. Update the file to handle URL sharing properly:

```swift
import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Validate that we have content to share
        if let content = contentText, !content.isEmpty {
            return true
        }
        
        // Check for URL attachments
        if let attachments = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = attachments.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        return true
                    }
                }
            }
        }
        
        return false
    }

    override func didSelectPost() {
        // Extract URL from the shared content
        var sharedUrl: String? = nil
        
        // Check text content first
        if let content = contentText, let url = extractUrlFromText(content) {
            sharedUrl = url
        }
        
        // Check attachments for URLs
        if sharedUrl == nil {
            if let attachments = extensionContext?.inputItems.first as? NSExtensionItem {
                if let attachments = attachments.attachments {
                    for attachment in attachments {
                        if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                                if let url = item as? URL {
                                    sharedUrl = url.absoluteString
                                    self.handleSharedUrl(sharedUrl!)
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
        
        // If we have a URL, handle it
        if let url = sharedUrl {
            handleSharedUrl(url)
        } else {
            // No valid content found
            let alert = UIAlertController(title: "Error", message: "No valid URL found to share", preferredStyle: .alert)
            alert.addAction(UIAlertController.Action(title: "OK", style: .default) { _ in
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            })
            present(alert, animated: true, completion: nil)
        }
    }

    private func extractUrlFromText(_ text: String) -> String? {
        // Simple URL extraction - look for http:// or https://
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first {
            return (text as NSString).substring(with: match.range)
        }
        
        // Fallback: check if text starts with http:// or https://
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            return text
        }
        
        return nil
    }

    private func handleSharedUrl(_ url: String) {
        // Save the URL to UserDefaults to be picked up by the main app
        let userDefaults = UserDefaults(suiteName: "group.info.wouter.sourceviewer")
        userDefaults?.set(url, forKey: "sharedUrl")
        userDefaults?.synchronize()
        
        // Open the main app with the URL
        if let appUrl = URL(string: "htmlviewer://open?url=#{url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""}") {
            var responder: UIResponder? = self as UIResponder
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(appUrl, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }
        
        // Complete the request
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    override func didSelectCancel() {
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
}
```

### 4. Add App Groups Capability

#### Step 1: Enable App Groups
1. Select the **Htmlviewer** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Add a new group: `group.info.wouter.sourceviewer`

#### Step 2: Enable App Groups for Share Extension
1. Select the **HtmlviewerShare** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Select the same group: `group.info.wouter.sourceviewer`

### 5. Update AppDelegate for URL Handling

**File:** `ios/Runner/AppDelegate.swift`

Add the following method to handle URLs from the share extension:

```swift
override func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Handle URL sharing
    print("AppDelegate: open URL called with: \(url.absoluteString)")
    
    // Check if this is from our share extension
    if url.scheme == "htmlviewer" {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            for item in queryItems {
                if item.name == "url", let urlValue = item.value {
                    sharedContent = [
                        "type": "url",
                        "content": urlValue
                    ]
                    break
                }
            }
        }
    } else {
        // Handle direct URL sharing
        sharedContent = [
            "type": "url",
            "content": url.absoluteString
        ]
    }
    
    return true
}
```

### 6. Update Main App to Check for Shared URLs

**File:** `lib/services/shared_content_manager.dart`

Add a method to check for URLs shared via the share extension:

```dart
static Future<String?> checkForSharedExtensionUrl() async {
  try {
    const MethodChannel channel = MethodChannel('info.wouter.sourceviewer/shared_content');
    final result = await channel.invokeMethod('getSharedContent');
    
    if (result != null && result is Map) {
      final contentMap = Map<String, dynamic>.from(result);
      if (contentMap['type'] == 'url' && contentMap['content'] != null) {
        return contentMap['content'] as String;
      }
    }
    return null;
  } catch (e) {
    print('Error checking for shared extension URL: $e');
    return null;
  }
}
```

## 🎨 App Icon Configuration

### 7. Ensure Proper App Icon Setup

1. **App Icon Assets:**
   - Ensure `Assets.xcassets/AppIcon.appiconset` contains all required icon sizes
   - Include 20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt, and 1024pt icons

2. **Share Extension Icon:**
   - Add a specific icon for the share extension
   - Create `HtmlviewerShare/Assets.xcassets/ShareIcon.imageset`
   - Include 20pt, 29pt, and 40pt icons

## 🔧 Additional Configuration

### 8. Update Entitlements

**File:** `ios/Runner/Runner.entitlements`

Add App Groups entitlement:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.info.wouter.sourceviewer</string>
    </array>
</dict>
</plist>
```

### 9. Update Share Extension Entitlements

**File:** `ios/HtmlviewerShare/HtmlviewerShare.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.info.wouter.sourceviewer</string>
    </array>
</dict>
</plist>
```

## 📋 Testing the Integration

### Manual Testing Steps

1. **Build and Run:**
   ```bash
   flutter build ios --release
   ```

2. **Install on Device:**
   - Use Xcode to install on a physical iOS device
   - Ensure both main app and share extension are installed

3. **Test Safari Sharing:**
   - Open Safari and navigate to a webpage
   - Tap the Share button
   - Look for the Htmlviewer icon in the share sheet
   - Select Htmlviewer and verify the URL is shared correctly

4. **Test URL Handling:**
   - Verify the app opens and loads the shared URL
   - Check that the URL appears in the input field
   - Verify the content is displayed correctly

## 🐛 Troubleshooting

### Common Issues and Solutions

#### Issue: App icon doesn't appear in share sheet
**Solutions:**
- Ensure App Groups are properly configured
- Verify Info.plist has correct NSExtensionActivationRule
- Check that all required icon sizes are present
- Ensure the share extension target is included in the build

#### Issue: URL not being passed to main app
**Solutions:**
- Verify App Groups are working (check UserDefaults)
- Ensure URL scheme is properly registered
- Check that URL handling code in AppDelegate is correct

#### Issue: Share extension crashes
**Solutions:**
- Check for proper error handling in ShareViewController
- Verify all required entitlements are present
- Ensure proper thread handling for UI operations

## ✅ Verification Checklist

- [ ] Info.plist updated with URL document types
- [ ] HTTP/HTTPS URL schemes added
- [ ] Share Extension target created in Xcode
- [ ] Share Extension Info.plist configured
- [ ] App Groups capability added to both targets
- [ ] Entitlements files updated
- [ ] App icons properly configured
- [ ] URL handling code added to AppDelegate
- [ ] Shared content manager updated
- [ ] Build succeeds without errors
- [ ] App icon appears in Safari share sheet
- [ ] URL sharing works correctly

## 📚 Additional Resources

- [Apple Share Extension Documentation](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [URL Scheme Reference](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app)

## 🎯 Expected Outcome

After completing all the steps in this guide:

1. **Htmlviewer app icon will appear in Safari's share sheet**
2. **Users can share URLs directly to Htmlviewer**
3. **Shared URLs will open automatically in the app**
4. **The app will display the shared web content**
5. **Full integration with existing sharing functionality**

The implementation provides a seamless user experience for sharing web content from Safari to Htmlviewer, matching the functionality available on Android and providing a consistent cross-platform experience.