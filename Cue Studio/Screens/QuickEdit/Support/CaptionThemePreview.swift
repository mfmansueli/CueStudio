//
//  CaptionThemePreview.swift
//  Cue Studio
//

import UIKit

/// These are real renderer pixels, not a separately styled SwiftUI approximation.
enum CaptionThemePreview {
    static func image(_ theme: CaptionTheme) -> UIImage? {
        let words = ["Sua", "ideia", "merece", "ganhar", "vida."]
        let settings = CaptionSettings(theme: theme)
        let emphasis = settings.followsWords ? WordEmphasis(words: words, index: 2, style: .color(.yellow)) : nil
        return CaptionCollectionRenderer.image(CaptionText.joined(words), settings: settings,
                                               frame: CGSize(width: 402, height: 714), emphasis: emphasis)
    }
}
