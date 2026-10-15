//
//  QualityRunSample.swift
//  Cue StudioTests
//

import Foundation

/// One thing written on a device for the script-quality measurement (`ScriptQualityDeviceTests`): a script, with what was sent, what it cost the
/// model's window and how long it took, or a batch of Find inspiration ideas. Kept whole (the texts too) so the metrics (`ScriptQualityMetrics`) can
/// be run again on an older run after they change, and so people can read what was written.
nonisolated struct QualityRunSample: Codable, Hashable, Sendable {
    /// One idea of a batch, as the card shows it.
    struct Idea: Codable, Hashable, Sendable {
        let title: String
        let angle: String
        let openingLine: String
        let angleKind: String?
        let topic: String?
    }

    /// "script" or "ideas".
    let kind: String
    /// The creator's own words for the run ("baseline", "after-1"): what the code was when it was written.
    let run: String
    /// `CueLanguage.rawValue`.
    let language: String
    /// `QualityProfile.Condition.rawValue`, or "sweep" for the every-language sweep (`LanguageSweepCases`).
    let condition: String
    /// Which idea (scripts) or which batch (ideas).
    let index: Int
    let idea: String
    /// The idea came from Find inspiration with its angle and opening line.
    let hasBrief: Bool

    // What was sent.
    var instructions: String?
    var prompt: String?
    var instructionTokens: Int?
    var promptTokens: Int?
    var schemaTokens: Int?
    var contextSize: Int?
    var responseCap: Int?
    var minimumWords: Int?
    var askedWords: [Int]?
    var voiceTrimmed: [String]?
    /// How long the model's own count of the request took (`OnDeviceMeasure`), in milliseconds.
    var countMilliseconds: Double?

    // What came back.
    var title: String?
    var text: String?
    var discardedDraft: String?
    /// The script before its faulty block was written again (the repair the `after-1` run tried, since removed).
    var unrepairedText: String?
    var progressionDefects: [String]?
    /// Blocks written again (the `after-1` run's repair, since removed).
    var repairedBlocks: Int?
    var emptyReason: String?
    var attempts: Int?
    var violations: [String]?
    var expandedBlocks: Int?
    var voiceUse: String?
    var outputTokens: Int?
    var ideas: [Idea]?
    var failure: String?

    // How long.
    var seconds: Double
    var firstResponse: Double?

    var wasWritten: Bool { text?.isEmpty == false || ideas?.isEmpty == false }
}
