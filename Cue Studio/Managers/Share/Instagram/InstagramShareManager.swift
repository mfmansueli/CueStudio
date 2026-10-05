//
//  InstagramShareManager.swift
//  Cue Studio
//

import Foundation

/// Meta's "Sharing to Reels" and "Sharing to Stories" for iOS: the video's data goes on the general pasteboard under
/// `com.instagram.sharedSticker.backgroundVideo` (it expires in five minutes), and `instagram-reels://share` or
/// `instagram-stories://share?source_application=<Meta app ID>` opens the composer.
///
/// Limits of the documentation, kept honest here: the Reels page documents `backgroundVideo`; the Stories page lists a
/// background video in its asset table but shows iOS code only for images, so the Stories video key is the same name by
/// analogy and needs checking on a device. Neither page offers a callback, so the best this can report is `.opened`.
@MainActor
final class InstagramShareManager: InstagramSharing {
    static let videoKey = "com.instagram.sharedSticker.backgroundVideo"
    static let appIDKey = "com.instagram.sharedSticker.appID"
    /// Meta: "set the pasteboard expiration to 5 minutes".
    static let pasteboardLifetime: TimeInterval = 5 * 60

    private let apps: ExternalAppOpening
    private let pasteboard: PasteboardWriting
    private let now: () -> Date

    init(apps: ExternalAppOpening, pasteboard: PasteboardWriting = SystemPasteboard(), now: @escaping () -> Date = Date.init) {
        self.apps = apps
        self.pasteboard = pasteboard
        self.now = now
    }

    func share(videoAt url: URL, to surface: InstagramSurface, appID: String) async -> ShareOutcome {
        guard let target = Self.url(for: surface, appID: appID) else { return .failed(.unknown) }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return .failed(.unknown) }
        // Reels reads the App ID from the pasteboard, Stories from the URL; sending both does no harm.
        pasteboard.setItems([[Self.videoKey: data, Self.appIDKey: appID]], expiresAt: now().addingTimeInterval(Self.pasteboardLifetime))
        guard await apps.open(target) else {
            // Instagram isn't there: the video doesn't stay on the pasteboard for anyone to paste.
            pasteboard.clear()
            return .unavailable(.appNotInstalled)
        }
        return .opened
    }

    static func url(for surface: InstagramSurface, appID: String) -> URL? {
        switch surface {
        case .reels: URL(string: "instagram-reels://share")
        case .stories: URL(string: "instagram-stories://share?source_application=\(appID)")
        }
    }
}
