//
//  VoicePreview.swift
//  Cue Studio
//

import Foundation

/// A script just written in the creator's voice is its own preview: "My Cue Voice" or "Without",
/// the same idea written neutrally for comparison, until they say "Sounds like me".
struct VoicePreview: Equatable {
    enum Showing: Equatable { case mine, without }

    /// The request the script was written from, to write the neutral version of it.
    var request: ScriptRequest
    var showing: Showing = .mine
    /// The same idea with no voice; nil until it is asked for.
    var without: String?
    var isLoadingWithout = false
}
