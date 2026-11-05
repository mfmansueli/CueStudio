//
//  VoicePreview.swift
//  Cue Studio
//

import Foundation

/// A script just written in the creator's voice is its own preview: "My voice" or "Without",
/// the same idea written neutrally for comparison, until they say "Sounds like me".
struct VoicePreview: Equatable {
    enum Showing: Equatable { case mine, without }

    /// The request the script was written from, to write the neutral version of it.
    var request: ScriptRequest
    var showing: Showing = .mine
    /// The same idea with no voice; nil until it is written (in the background once the script has arrived, or when "Without" is asked for).
    var without: String?
    var isLoadingWithout = false

    /// "Without" is chosen and its words aren't there yet: the page keeps the voiced words, dimmed, and says it is writing.
    var isWaitingForWithout: Bool { showing == .without && without == nil }
}
