//
//  UltraStudyVariant.swift
//  Cue StudioTests
//

import Foundation

/// A change to what Ultra is asked, tried only in the study (`UltraStudyPrompt`), never in the app: whether a fuller format definition, the
/// idea's kind or a kept title would write better. Each one names the exact words of the app's prompt it replaces or follows, and fails when
/// they aren't there, so a variant is never measured without having been applied.
nonisolated enum UltraStudyVariant: String, Codable, Sendable, CaseIterable {
    /// The chosen format's one-line label replaced by what the format needs (`UltraStudyFormats`).
    case formatFull
    /// The idea's kind (story, opinion, myth…) said after its subject: the app keeps it from the writer today.
    case angleKind
    /// On Auto, the app's "read the genre" line replaced by the genre's definition: the idea's kind's own, or every genre's in short for a
    /// typed idea (`UltraStudyAutoGenres`).
    case autoFull
    /// The idea's title stays the script's title, and the script must deliver what it promises.
    case titleKeep
    /// The editor writes a subtitle for the idea's title instead of a new title.
    case titleSubtitle
}
