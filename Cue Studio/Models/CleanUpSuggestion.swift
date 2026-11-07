//
//  CleanUpSuggestion.swift
//  Cue Studio
//

import Foundation

/// Something Clean Up found that could be cut. Only a suggestion: nothing leaves the edit until
/// the creator removes it, which takes its span out of the timeline like any other cut (and undo
/// brings it back). A pause can be dramatic and "like" can mean something, so the creator decides.
nonisolated struct CleanUpSuggestion: Codable, Hashable, Identifiable, Sendable {
    /// From this confidence up a suggestion is sure enough for "Remove all"; below it, it waits
    /// for the creator to listen.
    static let sureConfidence = 0.8

    var id = UUID()
    var kind: CleanUpKind
    /// Seconds of the recording it was heard in.
    var span: TimeSpan
    /// That recording: nil for the take, else another recording of the montage (`ClipSource.id`). Suggestions saved before
    /// montages were listened to are the take's.
    var sourceID: UUID?
    /// What was said ("um", "let me start again"); nil for pauses.
    var text: String?
    /// 0 to 1: how sure the detector is.
    var confidence: Double
    var status: CleanUpStatus = .pending
    /// What a removal took out of the recording, set when it was removed: a pause's cut depends on "Gap left" at that moment,
    /// so Put back, the Removed list and the time it saved use this, and a later change of the gap never moves it. Nil for one
    /// removed before the gap existed (its `span`) and while it isn't removed.
    var removedSpan: TimeSpan?
    /// One of the tries at a line of the script (`ScriptRetakeDetector`); nil for every other suggestion.
    var attempt: Attempt?

    /// A try at a script line said more than once: which group of tries it is in, its place among them and the line.
    struct Attempt: Codable, Hashable, Sendable {
        /// Shared by every try at the same line.
        var group: UUID
        /// 1 for the first try said.
        var number: Int
        /// How many tries the group has.
        var count: Int
        /// The line of the script they all try, as written there.
        var line: String
    }

    init(
        id: UUID = UUID(), kind: CleanUpKind, span: TimeSpan, text: String? = nil, confidence: Double, status: CleanUpStatus = .pending,
        sourceID: UUID? = nil, attempt: Attempt? = nil
    ) {
        self.id = id
        self.attempt = attempt
        self.sourceID = sourceID
        self.kind = kind
        self.span = span
        self.text = text
        self.confidence = confidence
        self.status = status
    }

    var isSure: Bool { confidence >= Self.sureConfidence }

    /// "Long pause", "“um”", "Possible retake".
    var title: String {
        switch kind {
        case .pause: if isSure { String(localized: "Long pause") } else { String(localized: "Short pause") }
        case .filler: text.map { "“\($0)”" } ?? kind.label
        case .retake: kind.label
        }
    }

    /// Why a suggestion deserves a listen, or what was said in a retake.
    var note: String? {
        switch kind {
        case .pause: isSure ? nil : String(localized: "May be intentional, for emphasis")
        case .filler: isSure ? nil : String(localized: "Might carry meaning · listen first")
        case .retake: text.map { "“\($0)”" }
        }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, kind, span, text, confidence, status, sourceID, removedSpan, attempt
        /// Before statuses: kept or not.
        case isKept
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CleanUpKind.self, forKey: .kind)
        span = try container.decode(TimeSpan.self, forKey: .span)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        confidence = try container.decode(Double.self, forKey: .confidence)
        sourceID = try? container.decodeIfPresent(UUID.self, forKey: .sourceID)
        removedSpan = try? container.decodeIfPresent(TimeSpan.self, forKey: .removedSpan)
        attempt = try? container.decodeIfPresent(Attempt.self, forKey: .attempt)
        if let status = try container.decodeIfPresent(CleanUpStatus.self, forKey: .status) {
            self.status = status
        } else {
            status = try container.decodeIfPresent(Bool.self, forKey: .isKept) == true ? .kept : .pending
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(span, forKey: .span)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(sourceID, forKey: .sourceID)
        try container.encodeIfPresent(removedSpan, forKey: .removedSpan)
        try container.encodeIfPresent(attempt, forKey: .attempt)
    }
}
