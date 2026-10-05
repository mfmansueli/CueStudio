//
//  FakeInstagramSharing.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeInstagramSharing: InstagramSharing {
    private(set) var shared: [(url: URL, surface: InstagramSurface, appID: String)] = []
    var outcome: ShareOutcome = .opened

    func share(videoAt url: URL, to surface: InstagramSurface, appID: String) async -> ShareOutcome {
        shared.append((url, surface, appID))
        return outcome
    }
}
