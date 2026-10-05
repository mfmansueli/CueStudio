//
//  FakeTikTokSharing.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeTikTokSharing: TikTokSharing {
    private(set) var requests: [(assetID: String, redirectURI: String)] = []
    var sends = true
    private(set) var finished: (@MainActor @Sendable (ShareOutcome) -> Void)?

    func share(assetID: String, redirectURI: String, finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void) -> Bool {
        guard sends else { return false }
        requests.append((assetID, redirectURI))
        self.finished = finished
        return true
    }

    func handleCallback(_ url: URL) -> Bool { false }
}
