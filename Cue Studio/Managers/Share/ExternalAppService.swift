//
//  ExternalAppService.swift
//  Cue Studio
//

import UIKit

/// Opens TikTok, Instagram, YouTube or LinkedIn by their URL schemes. Opening doesn't need the
/// schemes declared in Info.plist (only asking in advance would), and it reports whether it worked.
@MainActor
@Observable
final class ExternalAppService: ExternalAppOpening {
    func open(_ destination: ShareDestination) async -> Bool {
        guard let url = destination.appURL else { return false }
        return await UIApplication.shared.open(url)
    }
}
