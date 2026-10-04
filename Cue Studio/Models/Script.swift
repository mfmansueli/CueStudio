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
    /// Written by AI about a factual topic: the read view asks for a fact check until the creator
    /// taps "Checked".
    var factCheck: Bool = false
    /// The language the script is written in; nil detects it from the text. Voice Following,
    /// captions and the prompter's direction follow it. Never changes the text: a script is never
    /// translated in place.
    var language: CueLanguage?
    /// The creator's topic this script belongs to (`OnboardingTopic.id`), picked by Cue on this iPhone or by the creator.
    /// Nil is not tagged yet; an empty string is "no topic", which Cue leaves alone.
    var topic: String?
    /// The audience comment this script answers ("Answer a comment").
    var comment: ScriptComment?

    init(
        id: UUID = UUID(), title: String, text: String, platform: Platform, type: ScriptType? = nil,
        version: Int = 1, folder: String? = nil, createdAt: Date = .now, updatedAt: Date = .now,
        factCheck: Bool = false, language: CueLanguage? = nil, topic: String? = nil,
        comment: ScriptComment? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.platform = platform
        self.type = type
        self.version = version
        self.folder = folder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.factCheck = factCheck
        self.language = language
        self.topic = topic
        self.comment = comment
    }

    /// Fields added after v1 are optional, so libraries saved by older builds still open.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        platform = try container.decode(Platform.self, forKey: .platform)
        type = try container.decodeIfPresent(ScriptType.self, forKey: .type)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        folder = try container.decodeIfPresent(String.self, forKey: .folder)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        factCheck = try container.decodeIfPresent(Bool.self, forKey: .factCheck) ?? false
        // A language this build doesn't know (saved by a newer one) reads as auto-detect.
        language = (try? container.decodeIfPresent(CueLanguage.self, forKey: .language)) ?? nil
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        comment = try? container.decodeIfPresent(ScriptComment.self, forKey: .comment)
    }

    var structure: ScriptStructure { type?.structure ?? .generic }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// First paragraph without cues, for list previews.
    var previewLine: String {
        CueParser.paragraphs(in: CueParser.stripCues(text)).first ?? ""
    }

    /// What "Share" sends: the title, a blank line and the script as written (cues included).
    var shareText: String { "\(displayTitle)\n\n\(text)" }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled script") : trimmed
    }
}
