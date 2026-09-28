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
    /// Seconds of the original recording.
    var span: TimeSpan
    /// What was said ("um", "let me start again"); nil for pauses.
    var text: String?
    /// 0 to 1: how sure the detector is.
    var confidence: Double
    var status: CleanUpStatus = .pending

    init(id: UUID = UUID(), kind: CleanUpKind, span: TimeSpan, text: String? = nil, confidence: Double, status: CleanUpStatus = .pending) {
        self.id = id
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
        case .pause: isSure ? String(localized: "Long pause") : String(localized: "Short pause")
        case .filler: text.map { "“\($0)”" } ?? kind.label
        case .retake: kind.label
        }
    }

    /// Why a suggestion deserves a listen, or what was said in a retake.
    var note: String? {
        switch kind {
        case .pause: isSure ? nil : String(localized: "May be intentional — for emphasis")
        case .filler: isSure ? nil : String(localized: "Might carry meaning — listen first")
        case .retake: text.map { "“\($0)”" }
        }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, kind, span, text, confidence, status
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
    }
}
