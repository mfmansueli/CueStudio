//
//  TextGrip.swift
//  Cue Studio
//

import Foundation

/// What a gesture took a text on the preview by: the text itself (one finger moves it, two also resize and turn it), its
/// corner handle (resizes and turns it round its middle) or a side tab (makes its lines longer or shorter, the other side
/// staying where it is).
enum TextGrip: Equatable {
    case body, corner, leading, trailing

    /// A side tab.
    var isSide: Bool { self == .leading || self == .trailing }
}
