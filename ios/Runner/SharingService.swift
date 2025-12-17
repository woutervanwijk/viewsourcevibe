import Flutter
import UIKit

public class SharingService: NSObject {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.htmlviewer.sharing", binaryMessenger: registrar.messenger())
        let instance = SharingService()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "shareText":
            shareText(call: call, result: result)
        case "shareHtml":
            shareHtml(call: call, result: result)
        case "shareFile":
            shareFile(call: call, result: result)
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
        
        DispatchQueue.main.async {
            let activityViewController = UIActivityViewController(
                activityItems: [text], 
                applicationActivities: nil
            )
            
            // Get the root view controller
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                rootViewController.present(activityViewController, animated: true, completion: nil)
                result(true)
            } else {
                result(FlutterError(code: "NO_ROOT_VC", 
                                   message: "No root view controller found", 
                                   details: nil))
            }
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
        
        DispatchQueue.main.async {
            // Create a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            
            do {
                try html.write(to: fileURL, atomically: true, encoding: .utf8)
                
                let activityViewController = UIActivityViewController(
                    activityItems: [fileURL], 
                    applicationActivities: nil
                )
                
                // Set the subject for email sharing
                activityViewController.setValue("Shared HTML Content", forKey: "subject")
                
                // Get the root view controller
                if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                    rootViewController.present(activityViewController, animated: true, completion: nil)
                    result(true)
                } else {
                    result(FlutterError(code: "NO_ROOT_VC", 
                                       message: "No root view controller found", 
                                       details: nil))
                }
            } catch {
                result(FlutterError(code: "FILE_ERROR", 
                                   message: "Failed to create temporary file: \(error.localizedDescription)", 
                                   details: nil))
            }
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
        
        let mimeType = args["mimeType"] as? String ?? "text/html"
        
        DispatchQueue.main.async {
            let fileURL = URL(fileURLWithPath: filePath)
            
            // Check if file exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let activityViewController = UIActivityViewController(
                    activityItems: [fileURL], 
                    applicationActivities: nil
                )
                
                // Get the root view controller
                if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                    rootViewController.present(activityViewController, animated: true, completion: nil)
                    result(true)
                } else {
                    result(FlutterError(code: "NO_ROOT_VC", 
                                       message: "No root view controller found", 
                                       details: nil))
                }
            } else {
                result(FlutterError(code: "FILE_NOT_FOUND", 
                                   message: "File not found at path: \(filePath)", 
                                   details: nil))
            }
        }
    }
}