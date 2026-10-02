//
//  ParagraphPlaceholder.swift
//  Cue Studio
//

import SwiftUI

/// What an empty paragraph asks for, at the size of the text that will replace it (scaled with
/// Dynamic Type the way the text view scales its own).
struct ParagraphPlaceholder: View {
    let text: String
    @ScaledMetric private var points: CGFloat

    init(text: String, points: Double) {
        self.text = text
        _points = ScaledMetric(wrappedValue: CGFloat(points), relativeTo: .body)
    }

    var body: some View {
        Text(text)
            .font(.system(size: points))
            .foregroundStyle(Palette.ink2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
