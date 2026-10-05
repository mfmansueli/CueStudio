//
//  FakeAppOpener.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeAppOpener: ExternalAppOpening {
    /// Apps "installed" on the fake device.
    var installed: Set<ShareDestination> = Set(ShareDestination.allCases)
    /// URL schemes the fake device can open (Instagram's composers by default).
    var openableSchemes: Set<String> = ["instagram-reels", "instagram-stories"]
    private(set) var opened: [ShareDestination] = []
    private(set) var openedURLs: [URL] = []
    /// Opening works but the system says no.
    var refusesToOpen = false

    func open(_ destination: ShareDestination) async -> Bool {
        guard installed.contains(destination), !refusesToOpen else { return false }
        opened.append(destination)
        return true
    }

    func open(_ url: URL) async -> Bool {
        guard !refusesToOpen, url.scheme.map({ openableSchemes.contains($0) }) == true else { return false }
        openedURLs.append(url)
        return true
    }
}
