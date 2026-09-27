//
//  CaptionStyleSample.swift
//  Cue Studio
//

import SwiftUI

/// A style's name drawn in that style, for the captions picker.
struct CaptionStyleSample: View {
    let style: CaptionStyle

    var body: some View {
        switch style {
        case .classic:
            Text(style.label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Palette.captionBox, in: RoundedRectangle(cornerRadius: 5))
        case .bold:
            Text(style.label.uppercased())
                .font(.footnote.weight(.heavy))
                .foregroundStyle(.white)
                .shadow(color: Palette.textShadow, radius: 3, y: 1)
        case .highlight:
            Text(style.label)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Palette.acc, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}
