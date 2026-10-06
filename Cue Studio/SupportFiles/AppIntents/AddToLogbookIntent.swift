//
//  AddToLogbookIntent.swift
//  Cue Studio
//

import AppIntents
import Foundation

/// "Add an idea to Cue": Siri (or Shortcuts) saves an idea in the Logbook without opening Cue; when the phrase doesn't carry the idea,
/// Siri asks for it. It waits there with the others, to write later.
struct AddToLogbookIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Logbook"
    static let description = IntentDescription("Saves an idea in your Logbook, to write later.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Idea", requestValueDialog: IntentDialog("What's the idea?"))
    var idea: String

    @Dependency private var logbook: LogbookService

    init() {}

    init(idea: String) {
        self.idea = idea
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard Self.save(idea, in: logbook) else { throw $idea.needsValueError(IntentDialog("What's the idea?")) }
        return .result(dialog: IntentDialog("Saved in your Logbook."))
    }

    /// The idea goes in as typed text would; blank words keep nothing. Returns whether something was saved.
    @MainActor
    static func save(_ idea: String, in logbook: LogbookService) -> Bool {
        logbook.add(idea) != nil
    }
}
