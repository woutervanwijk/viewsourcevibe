import Flutter
import UIKit

// Shared Content Handler for managing content shared from the share extension
class SharedContentHandler {
    static let shared = SharedContentHandler()
    private var channel: FlutterMethodChannel?
    private var sharedContent: [String: Any]?

    private init() {}

    func setup(methodChannel: FlutterMethodChannel) {
        self.channel = methodChannel
        
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSharedContent":
            handleGetSharedContent(result: result)
        case "clearSharedContent":
            handleClearSharedContent(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleGetSharedContent(result: @escaping FlutterResult) {
        guard let sharedContent = sharedContent else {
            result(nil)
            return
        }
        result(sharedContent)
        // Clear the content after retrieving it
        self.sharedContent = nil
    }

    private func handleClearSharedContent(result: @escaping FlutterResult) {
        sharedContent = nil
        result(true)
    }

    func setSharedContent(_ content: [String: Any]) {
        sharedContent = content
        
        // Notify Flutter side if channel is available
        channel?.invokeMethod("handleNewSharedContent", arguments: content)
    }

    func clearSharedContent() {
        sharedContent = nil
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up shared content handler
    setupSharedContentHandler()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupSharedContentHandler() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "info.wouter.sourceviewer/shared_content",
      binaryMessenger: controller.binaryMessenger
    )
    
    SharedContentHandler.shared.setup(methodChannel: channel)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Handle URL scheme calls from the share extension
    handleURLScheme(url: url)
    return true
  }

  private func handleURLScheme(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      return
    }

    // Handle viewsourcevibe://open?url=... scheme
    if components.scheme == "viewsourcevibe", 
       let host = components.host,
       let queryItems = components.queryItems {
      
      var sharedData: [String: Any] = [:]
      
      switch host {
      case "open":
        if let urlItem = queryItems.first(where: { $0.name == "url" }), 
           let urlValue = urlItem.value {
          sharedData = [
            "type": "url",
            "content": urlValue
          ]
        }
      case "text":
        if let contentItem = queryItems.first(where: { $0.name == "content" }), 
           let contentValue = contentItem.value {
          sharedData = [
            "type": "text",
            "content": contentValue
          ]
        }
      case "file":
        if let pathItem = queryItems.first(where: { $0.name == "path" }), 
           let pathValue = pathItem.value {
          sharedData = [
            "type": "file",
            "filePath": pathValue,
            "fileName": URL(fileURLWithPath: pathValue).lastPathComponent
          ]
        }
      default:
        break
      }

      if !sharedData.isEmpty {
        SharedContentHandler.shared.setSharedContent(sharedData)
      }
    }
  }
}
