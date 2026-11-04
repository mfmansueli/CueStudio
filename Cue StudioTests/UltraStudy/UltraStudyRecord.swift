//
//  UltraStudyRecord.swift
//  Cue StudioTests
//

import Foundation

/// What one job wrote (`UltraStudyTests`), saved as `out/<job id>.json`: the script and its title as the app would show them, every stage's
/// text, the editor's changes, each call whole (`UltraStudyCall`) and the outcome. A failure the model caused (a cut-off answer, a refusal)
/// is a result; a failure the API caused after its tries is saved apart (`failed/`) and written again on the next run.
nonisolated struct UltraStudyRecord: Codable, Sendable {
    let job: UltraStudyJob
    /// What `UltraPayload` would send for the draft before any variant: the study's check that it asks as the app asks.
    let appDraftPrompt: String
    var outcome = "ok"
    var title = ""
    var script = ""
    var draft = ""
    var checked: String?
    var corrections: [String] = []
    var changes: [String] = []
    /// The polished script before the fit, when a fit changed it.
    var beforeFit: String?
    var calls: [UltraStudyCall] = []
    var seconds = 0.0
    var finishedAt = Date()
}
