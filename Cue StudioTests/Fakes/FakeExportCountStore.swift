//
//  FakeExportCountStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeExportCountStore: ExportCountStoring {
    var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    func load() -> Int { count }

    func save(_ count: Int) { self.count = count }
}
