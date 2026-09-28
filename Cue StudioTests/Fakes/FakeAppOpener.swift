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
    private(set) var opened: [ShareDestination] = []

    func open(_ destination: ShareDestination) async -> Bool {
        guard installed.contains(destination) else { return false }
        opened.append(destination)
        return true
    }
}
