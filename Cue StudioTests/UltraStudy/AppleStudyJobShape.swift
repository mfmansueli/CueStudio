//
//  AppleStudyJobShape.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// An `AppleStudyJob` as the study's records name a job (`UltraStudyRecord.job`): blind.py, score.py and metrics.py read its case and its
/// arm (`config.id`) the same way for Ultra's scripts and Apple Intelligence's.
nonisolated struct AppleStudyJobShape: Codable, Sendable {
    nonisolated struct Arm: Codable, Sendable {
        let id: String
        let model: String
        let flow: String
    }

    let id: String
    let item: UltraStudyJob.Case
    let config: Arm
    let variants: [String]
    let repetition: Int

    private enum CodingKeys: String, CodingKey {
        case id, item = "case", config, variants, repetition
    }
}
