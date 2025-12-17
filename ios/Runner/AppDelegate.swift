import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register our custom sharing service
    SharingService.register(with: self.registrar(forPlugin: "SharingService")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
