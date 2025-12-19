import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var sharedContent: [String: Any]? = nil
  private let SHARED_CONTENT_CHANNEL = "info.wouter.sourceviewer/shared_content"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register our custom sharing service
    SharingService.register(with: self.registrar(forPlugin: "SharingService")!)

    // Setup channel for handling shared content
    let controller = window?.rootViewController as? FlutterViewController
    let channel = FlutterMethodChannel(
      name: SHARED_CONTENT_CHANNEL,
      binaryMessenger: controller!.binaryMessenger)

    channel.setMethodCallHandler {
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getSharedContent" {
        self?.handleSharedContent(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Check for shared content from UserDefaults (from share extension)
    checkForSharedContentFromUserDefaults()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func checkForSharedContentFromUserDefaults() {
    let userDefaults = UserDefaults(suiteName: "group.info.wouter.sourceviewer")
    
    if let sharedData = userDefaults?.dictionary(forKey: "sharedContent") {
      print("AppDelegate: Found shared content in UserDefaults: \(sharedData)")
      
      // Convert to the format expected by our app
      if let contentType = sharedData["type"] as? String {
        var processedData: [String: Any] = [
          "type": contentType
        ]
        
        // Map the shared content fields to our expected format
        if let content = sharedData["content"] as? String {
          processedData["content"] = content
        }
        
        if let url = sharedData["url"] as? String {
          processedData["content"] = url
        }
        
        if let text = sharedData["text"] as? String {
          processedData["content"] = text
        }
        
        if let filePath = sharedData["filePath"] as? String {
          processedData["filePath"] = filePath
        }
        
        if let fileName = sharedData["fileName"] as? String {
          processedData["fileName"] = fileName
        }
        
        // Set this as the initial shared content
        sharedContent = processedData
        
        // Clear the UserDefaults so we don't process it again
        userDefaults?.removeObject(forKey: "sharedContent")
        userDefaults?.synchronize()
        
        print("AppDelegate: Processed shared content from UserDefaults: \(processedData)")
      }
    }
  }

  private func handleSharedContent(result: FlutterResult) {
    guard let content = sharedContent else {
      result(nil)
      return
    }

    result(content)
    sharedContent = nil  // Clear after handling
  }
    
  override func application(
    _ application: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Handle URL sharing
    print("AppDelegate: open URL called with: \(url.absoluteString)")

    // Check if this is a file URL (shared file)
    // Handle both standard file URLs and file:/// URLs
    if url.isFileURL || url.scheme == "file" {
      print("AppDelegate: Handling file URL: \\(url.absoluteString)")
      
      // Convert file:// URL to file path
      var filePath = url.path
      if url.scheme == "file" && url.host != nil {
        // Handle file:///host/path format
        filePath = "/" + (url.host ?? "") + url.path
      }
      
      print("AppDelegate: Extracted file path: \\(filePath)")
      
      // Check if file exists
      if FileManager.default.fileExists(atPath: filePath) {
        sharedContent = [
          "type": "file",
          "filePath": filePath,
          "fileName": url.lastPathComponent
        ]
        print("AppDelegate: File shared successfully, path: \\(filePath)")
      } else {
        print("AppDelegate: File does not exist at path: \\(filePath)")
        return false
      }
    }
    // Check if this is from our share extension
    else if url.scheme == "viewsourcevibe" {
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
        let queryItems = components.queryItems
      {
        var contentType: String? = nil
        var content: String? = nil
        var fileName: String? = nil
        
        for item in queryItems {
          if item.name == "type", let typeValue = item.value {
            contentType = typeValue
          }
          else if item.name == "content", let contentValue = item.value {
            content = contentValue
          }
          else if item.name == "fileName", let fileNameValue = item.value {
            fileName = fileNameValue
          }
          else if item.name == "url", let urlValue = item.value {
            // Backward compatibility for old share extension format
            contentType = "url"
            content = urlValue
          }
        }
        
        if let type = contentType, let contentValue = content {
          var sharedData: [String: Any] = [
            "type": type,
            "content": contentValue
          ]
          
          if let name = fileName {
            sharedData["fileName"] = name
          }
          
          // Handle file paths specially
          if type == "file", let filePath = contentValue as? String {
            sharedData["filePath"] = filePath
          }
          
          sharedContent = sharedData
          print("AppDelegate: Share extension content received: \(sharedData)")
        }
      }
    } else {
      // Handle direct URL sharing
      sharedContent = [
        "type": "url",
        "content": url.absoluteString,
      ]
    }

    // Notify Flutter about the new shared content if app is running
    if let sharedContent = sharedContent {
      print("AppDelegate: Notifying Flutter about new shared content")
      
      // Get the root view controller to access the Flutter method channel
      if let rootViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: "info.wouter.sourceviewer/shared_content",
          binaryMessenger: rootViewController.binaryMessenger
        )
        
        channel.invokeMethod("handleNewSharedContent", arguments: sharedContent) { result in
          if let success = result as? Bool, success {
            print("AppDelegate: Flutter successfully processed shared content")
          } else {
            print("AppDelegate: Flutter failed to process shared content")
          }
        }
      } else {
        print("AppDelegate: Could not access Flutter method channel")
      }
    }

    return true
  }

}
