//
//  PrompterFont+Font.swift
//  Cue Studio
//

import SwiftUI

extension PrompterFont {
    func font(size: CGFloat) -> Font {
        switch self {
        case .lexend: CueStudioFont.lexend(size: size)
        case .legible: CueStudioFont.legible(size: size)
        case .serif: CueStudioFont.serif(size: size)
        case .rounded: CueStudioFont.rounded(size: size)
        }
    }
}
