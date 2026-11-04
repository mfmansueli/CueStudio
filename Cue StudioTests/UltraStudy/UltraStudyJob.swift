//
//  UltraStudyJob.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// One script the Ultra study writes (`UltraStudyTests`, owner's study of 04/11/2026: model and effort, formats, length, titles): the case
/// (who writes, what they asked, where it goes), the configuration that writes it (model and effort per stage), the prompt variants under test,
/// an optional length policy and which repetition it is. Read from the study's `jobs.json`, written by `tools/ultra/study/jobs.py`.
nonisolated struct UltraStudyJob: Codable, Sendable, Identifiable {
    /// What the creator asks for, as the app would send it.
    struct Case: Codable, Sendable {
        let id: String
        /// A `CueLanguage` raw value ("pt-BR", "en-US", "es-ES"): the script's and the interface's language.
        let language: String
        /// A creator of `UltraStudyCreators`.
        let creator: String
        let voice: QualityProfile.Condition
        /// The idea as the creator typed it; nil when it came from the card or Find inspiration (`brief`).
        let idea: String?
        let brief: Brief?
        /// A `Platform` raw value.
        let platform: String
        /// A `FormatChoice` id: "auto", "talking" or a `ScriptType` raw value.
        let format: String
        /// A `ScriptLength` raw value.
        let length: String
        let brand: Brand?
    }

    /// An idea of the card or Find inspiration, as the library holds it (`IdeaLibrary`).
    struct Brief: Codable, Sendable {
        let subject: String
        let angle: String
        let openingLine: String
        /// An `IdeaAngle` raw value.
        let angleKind: String
        /// A `Niche` raw value.
        let topicKey: String
    }

    /// A sponsored ad's facts (`BrandBrief`).
    struct Brand: Codable, Sendable {
        let name: String
        let product: String
        let mustSay: String
        let neverSay: String
        let link: String
        let code: String
    }

    /// Who writes and how much each stage thinks: a Claude model id and an effort ("low", "medium", "high") per stage.
    struct Config: Codable, Sendable {
        let id: String
        let model: String
        let draft: String
        let check: String
        let review: String
        /// An `UltraFlow` raw value: "checked" (three calls) or "polished" (two).
        let flow: String
    }

    /// A length policy in place of the request's own (`UltraLength`): "ideal", "required" or "free", with the range in seconds.
    struct Length: Codable, Sendable {
        let kind: String
        let low: Double?
        let high: Double?
    }

    let id: String
    let item: Case
    let config: Config
    let variants: [UltraStudyVariant]
    let length: Length?
    let repetition: Int

    private enum CodingKeys: String, CodingKey {
        case id, item = "case", config, variants, length, repetition
    }
}
