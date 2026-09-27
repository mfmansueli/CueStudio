//
//  RecognizedLine.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// One line of text found in a photo, with where it sits on the page (normalized, origin at the
/// top left).
nonisolated struct RecognizedLine: Hashable, Sendable {
    var text: String
    var box: CGRect
}
