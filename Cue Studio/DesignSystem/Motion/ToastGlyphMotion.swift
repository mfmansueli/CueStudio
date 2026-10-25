//
//  ToastGlyphMotion.swift
//  Cue Studio
//

import Foundation

/// Where a toast's glyph is in its gesture (`ToastIcon`): the ★ turning in, the ! shaking its head. At rest it is itself.
nonisolated struct ToastGlyphMotion: Sendable {
    var scale = 1.0
    var angle = 0.0
    var opacity = 1.0
}
