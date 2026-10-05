//
//  ExternalAppService.swift
//  Cue Studio
//

import UIKit

/// Opens TikTok, Instagram, YouTube or LinkedIn by their URL schemes. Opening is only that: it never means a video
/// arrived (see `VideoSharingService` for what does).
@MainActor
@Observable
final class ExternalAppService: ExternalAppOpening {
    func open(_ destination: ShareDestination) async -> Bool {
        guard let url = destination.appURL else { return false }
        return await UIApplication.shared.open(url)
    }

    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
