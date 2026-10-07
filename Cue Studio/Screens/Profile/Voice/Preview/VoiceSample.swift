//
//  VoiceSample.swift
//  Cue Studio
//

import Foundation

/// The three parts of the sample script the preview shows ("Does this sound like you?"), and the tags under it that say what shaped it.
struct VoiceSample: Equatable {
    var hook: String
    var body: String
    var cta: String
    /// What shaped it ("says “I”", "conversational", "question hook"…).
    var tags: [String] = []
}
