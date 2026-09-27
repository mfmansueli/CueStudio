//
//  RecordScriptIntent.swift
//  Cue Studio
//

import AppIntents
import Foundation

/// "Record script {name}": opens the camera with the script ready under the lens.
struct RecordScriptIntent: AppIntent {
    static let title: LocalizedStringResource = "Record script"
    static let description = IntentDescription("Opens the camera with the script ready to scroll under the lens.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Script")
    var script: ScriptEntity

    init() {}

    init(script: ScriptEntity) {
        self.script = script
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.record(script.id))
        return .result()
    }
}
