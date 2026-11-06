//
//  LogbookLiveCaption.swift
//  Cue Studio
//

import SwiftUI

/// The words heard while the Logbook listens, on the field's one line, like live captions: the newest at its end, the oldest gliding out
/// under a fade at its start. The field keeps its height while the finger is down, so the button never moves under it (owner, 05/11/2026);
/// the whole idea is read on its card, which lands open. Mirrored in a right-to-left language.
struct LogbookLiveCaption: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0

    /// The words are longer than the line: their end is kept in view and their start fades.
    private var overflows: Bool { lineWidth > boxWidth + 0.5 }

    var body: some View {
        Color.clear
            .overlay(alignment: overflows ? .trailing : .leading) {
                Text(verbatim: text)
                    .cueFont(17)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { lineWidth = $0 })
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { boxWidth = $0 })
            .mask {
                LinearGradient(
                    stops: [.init(color: overflows ? .clear : .black, location: 0), .init(color: .black, location: 0.16)],
                    startPoint: .leading, endPoint: .trailing
                )
                .flipsForRightToLeftLayoutDirection(true)
            }
            .clipped()
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: text)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("logbook.liveCaption")
    }
}
