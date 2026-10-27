//
//  TextEffectLayoutBox.swift
//  Cue Studio
//

import Foundation

/// A layout held by reference, for the cache (`NSCache` keeps objects).
nonisolated final class TextEffectLayoutBox: @unchecked Sendable {
    let layout: TextEffectLayout

    init(_ layout: TextEffectLayout) {
        self.layout = layout
    }
}
