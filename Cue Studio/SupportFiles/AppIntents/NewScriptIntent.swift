//
//  NewScriptIntent.swift
//  Cue Studio
//

import AppIntents
import Foundation

/// "New script": opens Cue on the ways to start one (prompt, write, import, themes, formats).
nonisolated struct NewScriptIntent: AppIntent {
    static let title: LocalizedStringResource = "New script"
    static let description = IntentDescription("Starts a new script from a prompt, a blank page or a document.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.newScript)
        return .result()
    }
}
