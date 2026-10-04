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
    /// UI tests (`-uiTestAppsInstalled`): every platform's app counts as installed and opens, so the send-off can be seen
    /// in a Simulator that has none of them.
    private let pretendsInstalled: Bool

    init(pretendsInstalled: Bool = false) {
        self.pretendsInstalled = pretendsInstalled
    }

    func open(_ destination: ShareDestination) async -> Bool {
        if pretendsInstalled { return true }
        guard let url = destination.appURL else { return false }
        return await UIApplication.shared.open(url)
    }
}
