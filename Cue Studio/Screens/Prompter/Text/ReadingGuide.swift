//
//  ReadingGuide.swift
//  Cue Studio
//

import SwiftUI

/// The reading line over the text: the horizon (a glowing yellow line with a small arrow at the left), with a
/// few specks of light rising from it while the text plays. When the text follows the voice, its glow
/// flickers with the level of the voice.
struct ReadingGuide: View {
    /// 0...1 voice level while recognition follows the voice; nil leaves the line breathing.
    var level: Double?
    /// Specks rise from the line while the text moves.
    var showsParticles = false

    var body: some View {
        HorizonLine(level: level)
            .frame(height: Self.height)
            .overlay(alignment: .bottom) {
                if showsParticles { HorizonParticles().frame(height: HorizonParticles.reach).offset(y: -Self.height / 2) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The line's box: tall enough for the arrow.
    static let height: CGFloat = 12
}

#if DEBUG
#Preview {
    ReadingGuide(level: nil, showsParticles: true).padding(.vertical, 40).background(.black)
}
#endif
