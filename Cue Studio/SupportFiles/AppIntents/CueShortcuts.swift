//
//  CueShortcuts.swift
//  Cue Studio
//

import AppIntents

/// Siri phrases and Shortcuts actions that work without setup.
nonisolated struct CueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordScriptIntent(),
            phrases: [
                "Record \(\.$script) in \(.applicationName)",
                "Read \(\.$script) with \(.applicationName)",
            ],
            shortTitle: "Record script",
            systemImageName: "video.fill"
        )
        AppShortcut(
            intent: NewScriptIntent(),
            phrases: [
                "New script in \(.applicationName)",
                "Write a script with \(.applicationName)",
            ],
            shortTitle: "New script",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: AddToLogbookIntent(),
            phrases: [
                "Add an idea to \(.applicationName)",
                "Save an idea in \(.applicationName)",
            ],
            shortTitle: "Add to Logbook",
            systemImageName: "book.closed"
        )
    }
}
