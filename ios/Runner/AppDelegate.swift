import Flutter
import UIKit

// Sharing Service for handling native sharing functionality
class SharingService: NSObject {
    private static let channelName = "info.wouter.sourceview.sharing"
    private static var channel: FlutterMethodChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = SharingService()
        channel.setMethodCallHandler(instance.handle)
        self.channel = channel
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "shareText":
            shareText(call: call, result: result)
        case "shareHtml":
            shareHtml(call: call, result: result)
        case "shareFile":
            shareFile(call: call, result: result)
        case "shareUrl":
            shareUrl(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func shareText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "Text argument is required", 
                                details: nil))
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [text], 
            applicationActivities: nil
        )
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll
        ]

        // Get the root view controller
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
            result(true)
        } else {
            result(FlutterError(code: "NO_ROOT_VC", 
                                message: "Could not find root view controller", 
                                details: nil))
        }
    }

    private func shareHtml(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let html = args["html"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "HTML argument is required", 
                                details: nil))
            return
        }

        let filename = args["filename"] as? String ?? "shared_content.html"

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(filename)

        do {
            try html.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            let activityViewController = UIActivityViewController(
                activityItems: [tempFileURL], 
                applicationActivities: nil
            )
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .saveToCameraRoll
            ]

            // Get the root view controller
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                rootViewController.present(activityViewController, animated: true, completion: nil)
                result(true)
            } else {
                result(FlutterError(code: "NO_ROOT_VC", 
                                    message: "Could not find root view controller", 
                                    details: nil))
            }
        } catch {
            result(FlutterError(code: "SHARE_FAILED", 
                                message: "Failed to share HTML: \(error.localizedDescription)", 
                                details: nil))
        }
    }

    private func shareFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "filePath argument is required", 
                                details: nil))
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)

        // Check if file exists
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            result(FlutterError(code: "FILE_NOT_FOUND", 
                                message: "File not found at path: \(filePath)", 
                                details: nil))
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [fileURL], 
            applicationActivities: nil
        )
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll
        ]

        // Get the root view controller
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
            result(true)
        } else {
            result(FlutterError(code: "NO_ROOT_VC", 
                                message: "Could not find root view controller", 
                                details: nil))
        }
    }

    private func shareUrl(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                                message: "Valid URL argument is required", 
                                details: nil))
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [url], 
            applicationActivities: nil
        )
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll
        ]

        // Get the root view controller
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
            result(true)
        } else {
            result(FlutterError(code: "NO_ROOT_VC", 
                                message: "Could not find root view controller", 
                                details: nil))
        }
    }
}

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
        case "hasSharedContent":
            // Non-destructive peek: returns true if content is pending, without consuming it
            result(sharedContent != nil)
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
    if let controller = window?.rootViewController as? FlutterViewController {
        setupServices(with: controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Sets up custom services for the given FlutterViewController
  func setupServices(with controller: FlutterViewController) {
      setupSharedContentHandler(with: controller)
      SharingService.register(with: controller.registrar(forPlugin: "SharingService")!)
  }

  func setupSharedContentHandler(with controller: FlutterViewController) {
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
    // Handle URL scheme calls from the share extension or Safari.
    // NOTE: With no UIApplicationSceneManifest in Info.plist, iOS routes URL
    // opens through this AppDelegate method (not SceneDelegate), so app_links'
    // application(_:open:options:) delegate fires correctly for cold starts.
    handleURLScheme(url: url)
    return super.application(app, open: url, options: options)
  }

  private func handleURLScheme(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
        return
    }

    if components.scheme == "viewsourcevibe",
       let host = components.host,
       let queryItems = components.queryItems {

      var sharedData: [String: Any] = [:]

      switch host {
      case "open":
        if let urlItem = queryItems.first(where: { $0.name == "url" }),
           let urlValue = urlItem.value,
           let decodedUrl = urlValue.removingPercentEncoding {
          sharedData = ["type": "url", "content": decodedUrl]
        }
      case "text":
        if let contentItem = queryItems.first(where: { $0.name == "content" }),
           let contentValue = contentItem.value,
           let decodedContent = contentValue.removingPercentEncoding {
          sharedData = ["type": "text", "content": decodedContent]
        }
      case "file":
        if let pathItem = queryItems.first(where: { $0.name == "path" }),
           let pathValue = pathItem.value,
           let decodedPath = pathValue.removingPercentEncoding {
          var filePath = decodedPath
          if filePath.hasPrefix("file:///") {
              filePath = String(filePath.dropFirst(7))
          } else if filePath.hasPrefix("file://") {
              filePath = String(filePath.dropFirst(6))
          }
          sharedData = [
            "type": "file",
            "filePath": filePath,
            "fileName": URL(fileURLWithPath: filePath).lastPathComponent
          ]
        }
      default:
        break
      }

      if !sharedData.isEmpty {
        SharedContentHandler.shared.setSharedContent(sharedData)
      }
    } else if components.scheme == "http" || components.scheme == "https" {
        SharedContentHandler.shared.setSharedContent([
            "type": "url",
            "content": url.absoluteString
        ])
    }
  }
}
