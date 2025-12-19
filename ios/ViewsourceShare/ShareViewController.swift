//
//  ShareViewController.swift
//  ViewsourceShare
//
//  Created by Wouter van Wijk on 19/12/2025.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private var isProcessing = false
    private var processingError: Error?
    private var hasProcessedContent = false

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        // If automatic processing didn't work, allow manual processing as fallback
        if !isProcessing && !hasProcessedContent {
            processSharedContent()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Start processing immediately when the view loads
        // This helps minimize the visibility of the share extension UI
        if !isProcessing && !hasProcessedContent {
            processSharedContent()
        }
    }

    override func configurationItems() -> [Any]! {
        // No configuration items needed for automatic processing
        return []
    }

    func processSharedContent() {
        // Prevent multiple processing attempts
        if isProcessing || hasProcessedContent {
            return
        }
        
        isProcessing = true
        processingError = nil
        hasProcessedContent = true
        
        // Show loading indicator
        showLoadingIndicator()

        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithError(error: NSError(domain: "ViewsourceShare", code: 1, userInfo: [NSLocalizedDescriptionKey: "No shared content found"]))
            return
        }

        // Process all attachments
        let dispatchGroup = DispatchGroup()
        var processedContent: [String: Any] = [:]
        var hasValidContent = false

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else {
                continue
            }

            for attachment in attachments {
                dispatchGroup.enter()
                
                // Check for URL content
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    handleURL(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["url"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling URL: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                // Check for HTML content
                else if attachment.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                    handleHTML(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["html"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling HTML: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                // Check for text content
                else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) || 
                          attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    handleText(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["text"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling text: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                // Check for CSS content
                else if attachment.hasItemConformingToTypeIdentifier("public.css") {
                    handleCSS(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["css"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling CSS: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                // Check for JavaScript content
                else if attachment.hasItemConformingToTypeIdentifier("public.javascript") {
                    handleJavaScript(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["javascript"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling JavaScript: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                // Check for file content
                else if attachment.hasItemConformingToTypeIdentifier("public.file-url") {
                    handleFileURL(attachment: attachment) { result in
                        switch result {
                        case .success(let content):
                            processedContent["file"] = content
                            hasValidContent = true
                        case .failure(let error):
                            print("Error handling file URL: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
                else {
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.hideLoadingIndicator()
            self.isProcessing = false
            
            if hasValidContent {
                // Try to open the main app with the shared content
                if let urlContent = processedContent["url"] as? String {
                    self.openURLInMainApp(url: urlContent)
                } else if let textContent = processedContent["text"] as? String {
                    self.openTextInMainApp(text: textContent)
                } else if let fileContent = processedContent["file"] as? String {
                    self.openFileInMainApp(filePath: fileContent)
                } else if let htmlContent = processedContent["html"] as? String {
                    self.openTextInMainApp(text: htmlContent)
                }
                
                // Give the main app a moment to open, then complete the request
                // This provides a smoother user experience
                // Use a slightly shorter delay since we're processing earlier
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else {
                // If no valid content, show error and complete after a short delay
                self.completeWithError(error: NSError(domain: "ViewsourceShare", code: 2, userInfo: [NSLocalizedDescriptionKey: "No valid content to share"]))
                
                // Complete the request after error is shown
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.extensionContext!.cancelRequest(withError: NSError(domain: "ViewsourceShare", code: 2, userInfo: [NSLocalizedDescriptionKey: "No valid content to share"]))
                }
            }
        }
    }

    func handleURL(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let url = item as? URL {
                print("Received URL: \(url.absoluteString)")
                completion(.success(url.absoluteString))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"])))
            }
        }
    }

    func handleHTML(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.html.identifier, options: nil) { (item, error) in
            if let error = error {
                print("Error loading HTML: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let htmlString = item as? String {
                print("Received HTML: \(htmlString)")
                completion(.success(htmlString))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid HTML format"])))
            }
        }
    }

    func handleText(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (item, error) in
            if let error = error {
                print("Error loading text: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let text = item as? String {
                print("Received text: \(text)")
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid text format"])))
            }
        }
    }

    func handleCSS(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: "public.css", options: nil) { (item, error) in
            if let error = error {
                print("Error loading CSS: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let cssString = item as? String {
                print("Received CSS: \(cssString)")
                completion(.success(cssString))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid CSS format"])))
            }
        }
    }

    func handleJavaScript(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: "public.javascript", options: nil) { (item, error) in
            if let error = error {
                print("Error loading JavaScript: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let jsString = item as? String {
                print("Received JavaScript: \(jsString)")
                completion(.success(jsString))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 7, userInfo: [NSLocalizedDescriptionKey: "Invalid JavaScript format"])))
            }
        }
    }

    func handleFileURL(attachment: NSItemProvider, completion: @escaping (Result<String, Error>) -> Void) {
        attachment.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
            if let error = error {
                print("Error loading file URL: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let url = item as? URL {
                print("Received file URL: \(url.absoluteString)")
                completion(.success(url.absoluteString))
            } else {
                completion(.failure(NSError(domain: "ViewsourceShare", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL format"])))
            }
        }
    }

    func openURLInMainApp(url: String) {
        // Use URL scheme to open the main app with the URL
        let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let appURL = URL(string: "viewsourcevibe://open?url=\(encodedURL)") {
            var responder = self as UIResponder?
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(appURL, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }
    }

    func openTextInMainApp(text: String) {
        // Use URL scheme to open the main app with text content
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let appURL = URL(string: "viewsourcevibe://text?content=\(encodedText)") {
            var responder = self as UIResponder?
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(appURL, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }
    }

    func openFileInMainApp(filePath: String) {
        // Use URL scheme to open the main app with file content
        let encodedFilePath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let appURL = URL(string: "viewsourcevibe://file?path=\(encodedFilePath)") {
            var responder = self as UIResponder?
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(appURL, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }
    }

    func showLoadingIndicator() {
        // Show loading indicator in the share extension
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        activityIndicator.tag = 999 // Unique tag for identification
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        // Disable user interaction during processing
        view.isUserInteractionEnabled = false
    }

    func hideLoadingIndicator() {
        // Hide loading indicator
        view.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
        
        // Re-enable user interaction
        view.isUserInteractionEnabled = true
    }

    func completeWithError(error: Error) {
        processingError = error
        hideLoadingIndicator()
        isProcessing = false
        
        // For automatic processing, we don't show an alert
        // The error will be handled by the completion handler
        print("Share extension error: \(error.localizedDescription)")
    }
}
