import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private var sharedContentType: String? = nil
    private var sharedContent: String? = nil
    private var sharedFilePath: String? = nil
    private var sharedFileName: String? = nil

    override func isContentValid() -> Bool {
        // Validate that we have content to share
        if let content = contentText, !content.isEmpty {
            return true
        }
        
        // Check for URL attachments
        if let attachments = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = attachments.attachments {
                for attachment in attachments {
                    // Check for URLs
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        return true
                    }
                    
                    // Check for files
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                        return true
                    }
                    
                    // Check for text
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        return true
                    }
                    
                    // Check for common file types
                    if #available(iOS 14.0, *) {
                        if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set a placeholder text
        placeholder = "Share URL or file with ViewSourceVibe"
        
        // Extract content in the background
        DispatchQueue.global(qos: .userInitiated).async {
            self.extractSharedContent()
        }
    }

    private func extractSharedContent() {
        // Check text content first
        if let content = contentText, !content.isEmpty {
            if let url = extractUrlFromText(content) {
                sharedContentType = "url"
                sharedContent = url
            } else {
                sharedContentType = "text"
                sharedContent = content
            }
            return
        }
        
        // Check attachments for various content types
        if let attachments = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = attachments.attachments {
                for attachment in attachments {
                    
                    // Handle URLs
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                            if let url = item as? URL {
                                self.sharedContentType = "url"
                                self.sharedContent = url.absoluteString
                            }
                        }
                        return
                    }
                    
                    // Handle file URLs
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                        attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { (item, error) in
                            if let fileURL = item as? URL {
                                self.handleFileURL(fileURL)
                            }
                        }
                        return
                    }
                    
                    // Handle text
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (item, error) in
                            if let text = item as? String {
                                self.sharedContentType = "text"
                                self.sharedContent = text
                            }
                        }
                        return
                    }
                    
                    // Handle data (for iOS 14+)
                    if #available(iOS 14.0, *) {
                        if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                            attachment.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { (item, error) in
                                if let data = item as? Data {
                                    self.handleFileData(data)
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
    }

    private func handleFileURL(_ fileURL: URL) {
        // Check if we can access the file
        if fileURL.startAccessingSecurityScopedResource() {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            // Copy the file to a temporary location that the main app can access
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = fileURL.lastPathComponent
            let destinationURL = tempDir.appendingPathComponent(fileName)
            
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                
                sharedContentType = "file"
                sharedFilePath = destinationURL.path
                sharedFileName = fileName
                
                print("ShareViewController: Successfully copied file to temp location: \(destinationURL.path)")
                
            } catch {
                print("ShareViewController: Error copying file: \(error)")
                
                // Fallback: just use the original file path
                sharedContentType = "file"
                sharedFilePath = fileURL.path
                sharedFileName = fileName
            }
        } else {
            // Couldn't access the file, but still try to pass the URL
            sharedContentType = "file"
            sharedFilePath = fileURL.path
            sharedFileName = fileURL.lastPathComponent
        }
    }

    private func handleFileData(_ data: Data) {
        // Save data to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "shared_file_" + UUID().uuidString + ".txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            sharedContentType = "file"
            sharedFilePath = fileURL.path
            sharedFileName = fileName
        } catch {
            print("ShareViewController: Error writing file data: \(error)")
        }
    }

    private func extractUrlFromText(_ text: String) -> String? {
        // Use NSDataDetector for robust URL extraction
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            if let match = matches.first {
                return (text as NSString).substring(with: match.range)
            }
        }
        
        // Fallback: check if text starts with http:// or https://
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.hasPrefix("http://") || trimmedText.hasPrefix("https://") {
            return trimmedText
        }
        
        // Fallback: check if text looks like a file path
        if trimmedText.hasPrefix("/") || trimmedText.hasPrefix("file://") {
            return trimmedText
        }
        
        return nil
    }

    override func didSelectPost() {
        // Check if we have extracted any content
        guard let contentType = sharedContentType else {
            showErrorAndComplete("No valid content found to share")
            return
        }
        
        // Save the shared content to UserDefaults for the main app to pick up
        let userDefaults = UserDefaults(suiteName: "group.info.wouter.sourceviewer")
        
        var sharedData: [String: Any] = [
            "type": contentType,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        switch contentType {
        case "url":
            if let url = sharedContent {
                sharedData["content"] = url
                sharedData["url"] = url
            }
        case "text":
            if let text = sharedContent {
                sharedData["content"] = text
                sharedData["text"] = text
            }
        case "file":
            if let filePath = sharedFilePath {
                sharedData["filePath"] = filePath
                sharedData["content"] = filePath
            }
            if let fileName = sharedFileName {
                sharedData["fileName"] = fileName
            }
        default:
            break
        }
        
        userDefaults?.set(sharedData, forKey: "sharedContent")
        userDefaults?.synchronize()
        
        print("ShareViewController: Saved shared content to UserDefaults: \(sharedData)")
        
        // Open the main app with the shared content
        openMainAppWithSharedContent(sharedData)
        
        // Complete the request
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func openMainAppWithSharedContent(_ sharedData: [String: Any]) {
        // Create a URL to open the main app
        var urlString = "viewsourcevibe://share?"
        
        // Add parameters based on content type
        if let contentType = sharedData["type"] as? String {
            urlString += "type=\(contentType)&"
        }
        
        if let content = sharedData["content"] as? String {
            if let encodedContent = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "content=\(encodedContent)&"
            }
        }
        
        if let fileName = sharedData["fileName"] as? String {
            if let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "fileName=\(encodedFileName)&"
            }
        }
        
        // Remove trailing & if present
        if urlString.hasSuffix("&") {
            urlString = String(urlString.dropLast())
        }
        
        if let appUrl = URL(string: urlString) {
            print("ShareViewController: Attempting to open main app with URL: \(appUrl.absoluteString)")
            
            var responder: UIResponder? = self as UIResponder
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(appUrl, options: [:]) { success in
                        if success {
                            print("ShareViewController: Successfully opened main app")
                        } else {
                            print("ShareViewController: Failed to open main app")
                            // Fallback: show message to user to open the app manually
                            DispatchQueue.main.async {
                                let alert = UIAlertController(
                                    title: "Shared Successfully",
                                    message: "Your content has been shared. Please open ViewSourceVibe to view it.",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                                })
                                self.present(alert, animated: true, completion: nil)
                            }
                        }
                    }
                    break
                }
                responder = responder?.next
            }
        }
    }

    private func showErrorAndComplete(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            })
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    override func didSelectCancel() {
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
}
