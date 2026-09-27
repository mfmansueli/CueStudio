//
//  Script.swift
//  Cue Studio
//

import Foundation

/// What the creator will say on camera. Scripts carry their destination, format and version; takes
/// are linked to the version they were recorded with.
nonisolated struct Script: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var text: String
    var platform: Platform
    var type: ScriptType?
    /// Bumped when the text changes after takes exist, so older takes stay tied to what was read.
    var version: Int = 1
    var folder: String?
    var createdAt: Date = .now
    var updatedAt: Date = .now

    var structure: ScriptStructure { type?.structure ?? .generic }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// First paragraph without cues, for list previews.
    var previewLine: String {
        CueParser.paragraphs(in: CueParser.stripCues(text)).first ?? ""
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled script") : trimmed
    }
}
