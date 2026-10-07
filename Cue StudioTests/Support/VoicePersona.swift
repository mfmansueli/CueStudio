//
//  VoicePersona.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A made-up creator the My Cue Voice measurements run on (`VoicePersonas`): a profile, three ideas to write and what a script
/// for them must and must not contain. The expectations are written by hand, not read from the profile or the app's own checker,
/// so they can grade the app. Shared by the brief snapshots (`VoiceBriefSnapshotTests`) and the device runs
/// (`VoicePersonaDeviceTests`).
nonisolated struct VoicePersona: Identifiable, Sendable, CustomTestStringConvertible {
    /// Who is talking in the script.
    enum Pronoun: String, Sendable {
        case i, we
    }

    let id: String
    /// One line a person reads to know who this is.
    let summary: String
    /// The language the ideas are written in, and so the script's.
    let language: CueLanguage
    /// What My Cue Voice holds today (the fields that existed before this work).
    var profile: CreatorProfile
    /// Three ideas for a video, in the persona's language.
    let ideas: [String]
    /// "I" or "we": what a script for this creator says, whatever the kind of creator would suggest.
    let pronoun: Pronoun
    /// Words and phrases a script must not contain (what `profile.avoid` and a typed "never write" stand for).
    let forbiddenTerms: [String]
    /// Words a script about their topics is likely to use (a few of them show the topics were heard).
    let topicTerms: [String]

    var testDescription: String { id }
}
