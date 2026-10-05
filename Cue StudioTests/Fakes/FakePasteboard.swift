//
//  FakePasteboard.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakePasteboard: PasteboardWriting {
    private(set) var items: [[String: Any]] = []
    private(set) var expiresAt: Date?
    private(set) var clears = 0

    func setItems(_ items: [[String: Any]], expiresAt: Date) {
        self.items = items
        self.expiresAt = expiresAt
    }

    func clear() {
        items = []
        clears += 1
    }
}
