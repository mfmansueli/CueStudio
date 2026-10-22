//
//  FakeApplicationGrace.swift
//  Cue StudioTests
//

import Foundation

/// Counts the background time asked for (`ApplicationGrace`) and given back, instead of asking iOS.
@MainActor
final class FakeApplicationGrace {
    private(set) var begun = 0
    private(set) var ended = 0

    /// Asked for and not given back yet.
    var isHeld: Bool { begun > ended }

    func begin() -> @MainActor () -> Void {
        begun += 1
        return { [weak self] in self?.ended += 1 }
    }
}
