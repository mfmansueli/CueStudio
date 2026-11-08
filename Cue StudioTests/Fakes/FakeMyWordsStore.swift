//
//  FakeMyWordsStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// My words in memory, so tests never write the simulator's defaults.
@MainActor
final class FakeMyWordsStore: MyWordsStoring {
    var words: MyWordsList {
        didSet { writes += 1 }
    }
    /// How many times the list was written.
    private(set) var writes = 0

    init(_ words: [String] = []) {
        self.words = MyWordsList(words)
    }
}
