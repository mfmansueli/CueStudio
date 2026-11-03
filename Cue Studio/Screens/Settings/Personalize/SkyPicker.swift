//
//  SkyPicker.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › Starry sky: the four skies as cards, two by two, each showing its own sky live (`SkyMiniature`) over its name
/// and what is in it, so a creator sees Adrift's comet before choosing it. The chosen card has the yellow ring and ✓ (`SelectionRing`), drawn
/// over the whole grid so it glides above the other cards to the next one, on a firm spring. One radio group for VoiceOver, its value the
/// chosen sky.
struct SkyPicker: View {
    @Binding var selection: SkyDensity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cards

    private static var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous) }

    var body: some View {
        // A `Grid`, so both cards of a row take the taller one's height when a line needs a third line ("…ein vorbeiziehendes
        // Raumschiff"; owner, 02/11/2026: no label is ever cut).
        let skies = SkyDensity.allCases
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: skies.count, by: 2)), id: \.self) { index in
                GridRow {
                    ForEach(skies[index..<min(index + 2, skies.count)]) { sky in
                        card(sky)
                    }
                }
            }
        }
        .selectionRing(on: selection, in: cards, shape: Self.cardShape, reduceMotion: reduceMotion)
        // Firm, barely past the card and back: the ring lands where it is going.
        .animation(reduceMotion ? CueMotion.fade : .spring(duration: 0.4, bounce: 0.12), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Starry sky"))
        .accessibilityValue(Text(selection.label))
        .accessibilityIdentifier("settings.starrySky")
    }

    /// What each sky has, in a few words.
    private func line(_ sky: SkyDensity) -> String {
        switch sky {
        case .off: String(localized: "Just the night")
        case .serene: String(localized: "Drifting stars and a soft nebula")
        case .adrift: String(localized: "Twinkles, a comet, an astronaut")
        case .interstellar: String(localized: "Deep space and a passing ship")
        }
    }

    private func card(_ sky: SkyDensity) -> some View {
        let isCurrent = selection == sky
        let shape = Self.cardShape
        return Button {
            guard !isCurrent else { return }
            selection = sky
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                SkyMiniature(density: sky)
                    .frame(height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(sky.label)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 4)
                Text(line(sky))
                    .cueFont(.caption)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2...)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(Palette.surface, in: shape)
            .selectionRingAnchor(sky, in: cards)
            .contentShape(shape)
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(sky.label))
        .accessibilityHint(Text(line(sky)))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("settings.starrySky.\(sky.rawValue)")
    }
}
