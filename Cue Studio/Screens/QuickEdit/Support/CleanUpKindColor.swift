//
//  CleanUpKindColor.swift
//  Cue Studio
//

import SwiftUI

/// Each kind of Clean Up suggestion has its color, on the timeline and in the list: pauses blue,
/// filler words orange, possible retakes red.
enum CleanUpKindColor {
    static func color(for kind: CleanUpKind) -> Color {
        switch kind {
        case .pause: Palette.info
        case .filler: Palette.warn
        case .retake: Palette.danger
        }
    }
}
