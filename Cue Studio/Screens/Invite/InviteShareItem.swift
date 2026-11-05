//
//  InviteShareItem.swift
//  Cue Studio
//

import LinkPresentation
import UIKit

/// The invite as the system share sheet hands it on (DESIGN_PROJECT §60): the message as a plain string the receiving app reads at once, the
/// invite's title over the sheet and as an email's subject. SwiftUI's `ShareLink` hands text over as data the app loads later, and WhatsApp's
/// extension couldn't take it (a gray screen that closed, then "Next" that did nothing; owner's recording, 05/11/2026); a plain string, as
/// Scripts shares a script, is what share extensions expect.
nonisolated final class InviteShareItem: NSObject, UIActivityItemSource, Sendable {
    let message: String
    let title: String

    init(message: String, title: String) {
        self.message = message
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        message
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        message
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    /// The sheet's header: the invite's title by Cue's icon, not the message's first line.
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        if let icon = UIImage(named: "AppIcon60x60") { metadata.iconProvider = NSItemProvider(object: icon) }
        return metadata
    }
}
