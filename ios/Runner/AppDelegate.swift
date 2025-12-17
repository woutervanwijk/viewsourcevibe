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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

    // Check if this is from our share extension
    if url.scheme == "htmlviewer" {
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
        let queryItems = components.queryItems
      {
        for item in queryItems {
          if item.name == "url", let urlValue = item.value {
            sharedContent = [
              "type": "url",
              "content": urlValue,
            ]
            break
          }
        }
      }
    } else {
      // Handle direct URL sharing
      sharedContent = [
        "type": "url",
        "content": url.absoluteString,
      ]
    }

    return true
  }

}
