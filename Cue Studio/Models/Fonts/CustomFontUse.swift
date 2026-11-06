//
//  CustomFontUse.swift
//  Cue Studio
//

import Foundation

/// An imported family at one weight, as an edit's words use it (`TakeEdit.customFontUses`).
nonisolated struct CustomFontUse: Hashable, Sendable {
    var family: String
    var weight: TextOverlayWeight
}
