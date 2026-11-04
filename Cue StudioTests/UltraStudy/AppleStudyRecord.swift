//
//  AppleStudyRecord.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What one `AppleStudyJob` wrote, in the study's record shape (`UltraStudyRecord`) with the route that answered.
nonisolated struct AppleStudyRecord: Codable, Sendable {
    let job: AppleStudyJobShape
    /// The request the writer got (its prompt; the instructions are kept apart): the judges' context.
    let appDraftPrompt: String
    let instructions: String
    var outcome = "ok"
    var title = ""
    var script = ""
    var draft = ""
    var calls: [String] = []
    /// The route that wrote it: a fallback to the other one is a result, not the arm.
    var model: String?
    var attempts = 0
    var seconds = 0.0
    var failure: String?
    var finishedAt = Date()
}
