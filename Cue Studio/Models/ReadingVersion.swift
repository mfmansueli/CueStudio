//
//  ReadingVersion.swift
//  Cue Studio
//

import Foundation

/// The versions a saved edit carries, in one table: how its numbers are read, so a take edited by an earlier Cue keeps looking
/// and sounding as the creator left it and a new edit gets today's. Each has the version new edits get (`current`), the first
/// one (`first`), and one rule for a save without the number (`read`): it was made before the number existed, so it reads as
/// the first (Adjust's dials only when they were used; an edit that never touched them gets today's). The saved numbers never
/// change meaning: a new way of reading is a new version.
nonisolated enum ReadingVersion: CaseIterable, Sendable {
    /// Adjust's dials (`LookSettings`, `FrameLook`): 1 the first numbers; 2 calibrated, gentle near zero.
    case look
    /// Studio Voice (`VoiceProcessing`): 1 one switch each; 2 the levels (equalizer and expander); 3 Reduce noise through
    /// Apple's voice isolation.
    case audio
    /// The caption styles' numbers (`CaptionStyleSpec`): 1 the first five presets; 2 the complete presets.
    case captionStyle
    /// How a take's words were heard (`CaptionTranscript`): 2 a script in more than one language is heard in each. An older
    /// transcript is heard again when captions are made.
    case captionTranscript
    /// Auto's measurement (`AutoCorrection`): a correction from a newer version means numbers this one can't read, and is
    /// left out rather than drawn wrong.
    case autoCorrection

    /// What a new edit is made with.
    var current: Int {
        switch self {
        case .look: 2
        case .audio: 3
        case .captionStyle: 2
        case .captionTranscript: 2
        case .autoCorrection: 1
        }
    }

    var first: Int { 1 }

    /// The version a saved part was made with: its own number, else the first (it was saved before the number existed), or
    /// today's when nothing in it depends on the reading (`usedOldNumbers` false).
    func read(_ saved: Int?, usedOldNumbers: Bool = true) -> Int {
        saved ?? (usedOldNumbers ? first : current)
    }

    /// Whether a saved part reads as today's: what was made by an older version is made again where Cue can (a transcript).
    func isCurrent(_ saved: Int?) -> Bool {
        read(saved) >= current
    }

    /// Whether this version of Cue knows how to read `version`: a newer one's numbers may mean something else.
    func knows(_ version: Int) -> Bool {
        version <= current
    }
}
