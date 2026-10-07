//
//  WritingStyleReading.swift
//  Cue Studio
//

import Foundation

/// Reads the creator's writing for what counting can't tell (how they sound, what about, who to), with the model on this iPhone. Behind a
/// protocol so the import can be tested without one, and so a device with no Apple Intelligence still imports: it just has fewer findings.
@MainActor
protocol WritingStyleReading: AnyObject {
    /// Whether the model can read right now (it is ready, writes `language`, and nothing the creator is waiting for is running).
    func canRead(language: String?) -> Bool

    /// What the model says of `samples` (a few texts, each shortened); nil when it can't or won't. Never throws: the import goes on without it.
    func read(_ samples: [String], language: String?) async -> StyleReading?
}
