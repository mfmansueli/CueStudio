//
//  SavedStyle.swift
//  Cue Studio
//

import Foundation

/// A style the creator saved under a name: a caption combination (`MyCaptionStyle`), a text's look (`TextLook`) or a cover's
/// (`CoverStyle`). A video that wears it keeps its own copy: renaming, updating or deleting it never changes a video already
/// made.
nonisolated struct SavedStyle<Look: Codable & Hashable & Sendable>: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var look: Look
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, look: Look, at date: Date = .now) {
        self.id = id
        self.name = name
        self.look = look
        createdAt = date
        updatedAt = date
    }

    var key: StyleKey { .saved(id) }
}
