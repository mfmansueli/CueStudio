//
//  CoverStudioSelection.swift
//  Cue Studio
//

import Foundation

/// What is picked on Cover Studio's canvas: the title, one graphic, or the divider of a before/after.
enum CoverStudioSelection: Hashable {
    case title
    case item(UUID)
    case divider

    var itemID: UUID? {
        if case .item(let id) = self { return id }
        return nil
    }
}
