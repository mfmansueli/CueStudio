//
//  ScriptEntityQuery.swift
//  Cue Studio
//

import AppIntents
import Foundation

/// Finds scripts for Siri and Shortcuts, by id, by name, or the most recent ones as suggestions.
/// Reads the same library the app shows, registered as an App Intents dependency at launch.
struct ScriptEntityQuery: EntityStringQuery {
    @Dependency private var library: ScriptLibraryService

    func entities(for identifiers: [UUID]) async throws -> [ScriptEntity] {
        await MainActor.run {
            library.scripts.filter { identifiers.contains($0.id) }.map(ScriptEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [ScriptEntity] {
        await MainActor.run {
            ScriptFilter.apply(.all, query: string, to: library.scripts).map(ScriptEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ScriptEntity] {
        await MainActor.run {
            library.scripts.prefix(10).map(ScriptEntity.init)
        }
    }
}
