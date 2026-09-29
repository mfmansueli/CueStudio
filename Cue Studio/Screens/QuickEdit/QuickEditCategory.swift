//
//  QuickEditCategory.swift
//  Cue Studio
//

import Foundation

/// Quick edit's tools grouped by intent, along the bottom: cut it down (Edit), put things on it
/// (Add), make it look and sound finished (Polish), Captions and Cover. A category with one tool
/// opens it straight away; the others show their tools in a row above.
enum QuickEditCategory: String, CaseIterable, Identifiable {
    case edit, add, polish, captions, cover

    var id: String { rawValue }

    var label: String {
        switch self {
        case .edit: String(localized: "Edit")
        case .add: String(localized: "Add")
        case .polish: String(localized: "Polish")
        case .captions: String(localized: "Captions")
        case .cover: String(localized: "Cover")
        }
    }

    var systemImage: String {
        switch self {
        case .edit: "scissors"
        case .add: "plus.square.on.square"
        case .polish: "wand.and.stars"
        case .captions: "captions.bubble"
        case .cover: "photo.on.rectangle"
        }
    }

    /// In the order they show.
    var tools: [QuickEditTool] {
        QuickEditTool.allCases.filter { $0.category == self }
    }
}
