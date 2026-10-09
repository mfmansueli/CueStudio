//
//  CaptionThemePreview.swift
//  Cue Studio
//

import UIKit

/// These are real renderer pixels, not a separately styled SwiftUI approximation.
enum CaptionThemePreview {
    private static let words = ["Sua", "ideia", "merece", "ganhar", "vida."]

    static func image(_ theme: CaptionTheme) -> UIImage? {
        image(CaptionSettings(theme: theme))
    }

    /// The collection as it is set (a text's look copied onto it too), at its default size and place,
    /// so the card shows the look and not where the lines sit.
    static func image(_ settings: CaptionSettings) -> UIImage? {
        var shown = settings
        shown.sizeScale = 1
        shown.center = nil
        let emphasis = shown.followsWords ? WordEmphasis(words: words, index: 2, style: .color(.yellow)) : nil
        return CaptionCollectionRenderer.image(CaptionText.joined(words), settings: shown,
                                               frame: CGSize(width: 402, height: 714), emphasis: emphasis)
    }
}
