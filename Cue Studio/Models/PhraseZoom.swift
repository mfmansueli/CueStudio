//
//  PhraseZoom.swift
//  Cue Studio
//

import Foundation

/// A zoom on a phrase (E4, owner 07/11/2026): started from caption lines, then on its own. It keeps the seconds of the recording
/// the lines were said in, so a correction, a split or a deleted line leaves it where it was, and a cut before it doesn't move it
/// off the words; it never splits a clip and adds to the clip's own zoom. Limits (decided 08/11/2026, DESIGN_PROJECT §50):
/// - at least `minimumDuration`, so a short line doesn't jolt: a shorter phrase holds that long from its start;
/// - eases in and out over `ramp`, and at most 1.25× (`Strength.strong`), so a 1080p take stays sharp; with the clip's zoom,
///   never past `maximumTotal`;
/// - toward the middle of the frame, and toward the face only where the creator turned Follow face on (its crop already follows
///   the face); never turns Follow face on by itself;
/// - on whatever plays in the main video then, the take or an imported clip (pinned to that recording); photos and videos laid over
///   it, and the split screen's other side, aren't zoomed.
nonisolated struct PhraseZoom: Codable, Hashable, Identifiable, Sendable {
    enum Strength: String, LenientChoice, CaseIterable, Identifiable, Sendable {
        static let fallback = Strength.medium

        case subtle, medium, strong

        var id: String { rawValue }

        /// Times the frame's size at its full.
        var scale: Double {
            switch self {
            case .subtle: 1.1
            case .medium: 1.18
            case .strong: 1.25
            }
        }

        var label: String {
            switch self {
            case .subtle: String(localized: "Subtle")
            case .medium: String(localized: "Medium")
            case .strong: String(localized: "Strong")
            }
        }
    }

    /// The shortest a phrase zoom lasts, in seconds of the recording.
    static let minimumDuration: TimeInterval = 0.8
    /// How long it takes to go in, and to come back, in seconds of the edit.
    static let ramp: TimeInterval = 0.2
    /// With the clip's own zoom, never closer than this.
    static let maximumTotal: Double = 1.45

    var id = UUID()
    /// Seconds of the recording `sourceID` (nil: the take).
    var span: TimeSpan
    var sourceID: UUID?
    var strength: Strength = .medium

    init(id: UUID = UUID(), span: TimeSpan, sourceID: UUID? = nil, strength: Strength = .medium) {
        self.id = id
        self.span = span.duration < Self.minimumDuration ? TimeSpan(start: span.start, end: span.start + Self.minimumDuration) : span
        self.sourceID = sourceID
        self.strength = strength
    }

    private enum CodingKeys: String, CodingKey {
        case id, span, sourceID, strength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: (try? container.decode(UUID.self, forKey: .id)) ?? UUID(),
            span: try container.decode(TimeSpan.self, forKey: .span),
            sourceID: try? container.decodeIfPresent(UUID.self, forKey: .sourceID),
            strength: (try? container.decodeIfPresent(Strength.self, forKey: .strength)) ?? .medium
        )
    }
}
