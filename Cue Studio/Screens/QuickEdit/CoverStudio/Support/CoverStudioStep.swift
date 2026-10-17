//
//  CoverStudioStep.swift
//  Cue Studio
//

import Foundation

/// Cover Studio's steps, in the order a cover is made: the picture, a template, the title, the graphics, the finish. Any step
/// can be opened at any time; Next goes through them in order.
enum CoverStudioStep: String, CaseIterable, Identifiable {
    case image, template, text, elements, effects

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image: String(localized: "Picture", comment: "Cover Studio step")
        case .template: String(localized: "Template", comment: "Cover Studio step")
        case .text: String(localized: "Title", comment: "Cover Studio step")
        case .elements: String(localized: "Graphics", comment: "Cover Studio step")
        case .effects: String(localized: "Finish", comment: "Cover Studio step")
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .template: "rectangle.3.group"
        case .text: "textformat"
        case .elements: "arrow.down.right.circle"
        case .effects: "wand.and.stars"
        }
    }

    /// The step after this one; nil on the last.
    var next: CoverStudioStep? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}
