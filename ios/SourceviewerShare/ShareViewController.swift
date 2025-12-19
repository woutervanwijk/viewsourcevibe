import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    private var sharedContent: [Any] = []
    private var contentType: String?
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments
        return !contentText.isEmpty
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super.didSelectPost(), which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    override func willMove(toParent parent: UIViewController?) {
        // Called when the extension is about to move to a new parent view controller.
        // This will happen when the user switches to a different app extension.
    }

    override func didMove(toParent parent: UIViewController?) {
        // Called when the extension has moved to a new parent view controller.
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the appearance
        self.navigationController?.navigationBar.tintColor = UIColor.systemBlue
        self.view.tintColor = UIColor.systemBlue
        
        // Set placeholder text
        self.placeholder = "Share URL or text with View Source Vibe"
        
        // Process the shared content
        processSharedContent()
    }

    private func processSharedContent() {
        let content = extensionContext!.inputItems[0] as! NSExtensionItem
        let attachments = content.attachments ?? []
        
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                // Handle URL
                attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            self.textView.text = url.absoluteString
                            self.sharedContent.append(url)
                            self.contentType = "url"
                        }
                    }
                }
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) ||
                      attachment.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
                // Handle text
                attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (item, error) in
                    if let text = item as? String {
                        DispatchQueue.main.async {
                            self.textView.text = text
                            self.sharedContent.append(text)
                            self.contentType = "text"
                        }
                    }
                }
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeHTML as String) {
                // Handle HTML
                attachment.loadItem(forTypeIdentifier: kUTTypeHTML as String, options: nil) { (item, error) in
                    if let html = item as? String {
                        DispatchQueue.main.async {
                            self.textView.text = html
                            self.sharedContent.append(html)
                            self.contentType = "html"
                        }
                    }
                }
            }
        }
        
        // If no attachments, check for text in user defaults (for direct text sharing)
        if sharedContent.isEmpty {
            if let text = content.attributedContentText?.string {
                self.textView.text = text
                self.sharedContent.append(text)
                self.contentType = "text"
            }
        }
    }

    override func validateContent() {
        // Update UI based on content
        if sharedContent.isEmpty {
            self.textView.text = "No content to share"
        }
    }
}
