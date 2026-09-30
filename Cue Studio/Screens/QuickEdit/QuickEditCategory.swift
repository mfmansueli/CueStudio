//
//  QuickEditCategory.swift
//  Cue Studio
//

import Foundation

/// Quick edit's tools by intent, along the bottom: Edit, Text, Captions, Audio, Media and Adjust.
/// Finishing (the cover) opens from the top bar, next to Done.
enum QuickEditCategory: String, CaseIterable, Identifiable {
    case edit, text, captions, audio, media, adjust, finish

    var id: String { rawValue }

    /// The categories along the bottom, in order.
    static var toolbar: [QuickEditCategory] { [.edit, .text, .captions, .audio, .media, .adjust] }

    var label: String {
        switch self {
        case .edit: String(localized: "Edit")
        case .text: String(localized: "Text")
        case .captions: String(localized: "Captions")
        case .audio: String(localized: "Audio")
        case .media: String(localized: "Media")
        case .adjust: String(localized: "Adjust")
        case .finish: String(localized: "Finish")
        }
    }

    var systemImage: String {
        switch self {
        case .edit: "scissors"
        case .text: "textformat"
        case .captions: "captions.bubble"
        case .audio: "speaker.wave.2"
        case .media: "photo.on.rectangle.angled"
        case .adjust: "slider.horizontal.3"
        case .finish: "checkmark.seal"
        }
    }

    /// In the order they show.
    var tools: [QuickEditTool] {
        QuickEditTool.allCases.filter { $0.category == self }
    }
}
