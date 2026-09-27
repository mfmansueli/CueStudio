//
//  ScriptEntity.swift
//  Cue Studio
//

import AppIntents
import Foundation

/// A script as Siri and Shortcuts see it: its title and where it will be posted.
nonisolated struct ScriptEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Script"
    static let defaultQuery = ScriptEntityQuery()

    var id: UUID
    var title: String
    var platformName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(platformName)")
    }

    init(id: UUID, title: String, platformName: String) {
        self.id = id
        self.title = title
        self.platformName = platformName
    }

    @MainActor
    init(_ script: Script) {
        self.init(id: script.id, title: script.displayTitle, platformName: script.platform.label)
    }
}
