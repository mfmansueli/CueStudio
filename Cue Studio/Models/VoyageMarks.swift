//
//  VoyageMarks.swift
//  Cue Studio
//

import Foundation

/// What the first voyage keeps of its own (the rest it reads from the library, the takes and the shares): its stage, the practice,
/// a skipped Polish, the tips put away and the steps whose light was already shown on the card.
nonisolated struct VoyageMarks: Codable, Equatable, Sendable {
    var stage: VoyageStage
    /// The teleprompter played a script (the first flight's practice counts).
    var practiced = false
    /// "Skip this step" on Polish it.
    var skippedPolish = false
    /// The tips closed with ✕: each step's tip is closed for good.
    var closedTips: Set<VoyageStep> = []
    /// The steps whose segment already lit up on the card.
    var celebrated: Set<VoyageStep> = []

    init(stage: VoyageStage) {
        self.stage = stage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stage = try container.decodeIfPresent(VoyageStage.self, forKey: .stage) ?? .active
        practiced = try container.decodeIfPresent(Bool.self, forKey: .practiced) ?? false
        skippedPolish = try container.decodeIfPresent(Bool.self, forKey: .skippedPolish) ?? false
        closedTips = try container.decodeIfPresent(Set<VoyageStep>.self, forKey: .closedTips) ?? []
        celebrated = try container.decodeIfPresent(Set<VoyageStep>.self, forKey: .celebrated) ?? []
    }
}
