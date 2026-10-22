//
//  FakeExportCountStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeExportCountStore: ExportCountStoring {
    var count: Int
    /// The Keychain before the first unlock: `load` can't read the count.
    var isLocked = false

    init(count: Int = 0) {
        self.count = count
    }

    func load() -> Int? { isLocked ? nil : count }

    func save(_ count: Int) { self.count = count }
}
