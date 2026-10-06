//
//  PrompterFont+Font.swift
//  Cue Studio
//

import SwiftUI

extension PrompterFont {
    func font(size: CGFloat) -> Font {
        switch self {
        case .system: CueStudioFont.system(size: size)
        case .newYork: CueStudioFont.newYork(size: size)
        case .rounded: CueStudioFont.rounded(size: size)
        case .lexend: CueStudioFont.lexend(size: size)
        case .legible: CueStudioFont.legible(size: size)
        }
    }
}
