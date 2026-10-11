//
//  VoyageMarks.swift
//  Cue Studio
//

import Foundation

/// What the first voyage keeps of its own (the rest it reads from the library, the takes and the shares): its stage, the practice,
/// a skipped Polish, the first draft's tip seen and the steps already announced. A step's tip closed with ✕ is closed for the session
/// only (`FirstVoyageService`), so it isn't kept here.
nonisolated struct VoyageMarks: Codable, Equatable, Sendable {
    var stage: VoyageStage
    /// The teleprompter played a script (the first flight's practice counts).
    var practiced = false
    /// "Skip" on Polish it.
    var skippedPolish = false
    /// The tip on Cue's first draft ("A first draft. Yours to change.") was read: it shows once.
    var sawDraftTip = false
    /// The steps whose "✓ … · Next: …" notice already came (or that never have one), so none is said twice. Saved as `celebrated`, the
    /// name from when the card lit a segment for each.
    var announced: Set<VoyageStep> = []

    init(stage: VoyageStage) {
        self.stage = stage
    }

    private enum CodingKeys: String, CodingKey {
        case stage, practiced, skippedPolish, sawDraftTip
        case announced = "celebrated"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stage = try container.decodeIfPresent(VoyageStage.self, forKey: .stage) ?? .active
        practiced = try container.decodeIfPresent(Bool.self, forKey: .practiced) ?? false
        skippedPolish = try container.decodeIfPresent(Bool.self, forKey: .skippedPolish) ?? false
        sawDraftTip = try container.decodeIfPresent(Bool.self, forKey: .sawDraftTip) ?? false
        announced = try container.decodeIfPresent(Set<VoyageStep>.self, forKey: .announced) ?? []
    }
}
