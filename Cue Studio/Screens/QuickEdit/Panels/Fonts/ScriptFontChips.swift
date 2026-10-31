//
//  ScriptFontChips.swift
//  Cue Studio
//

import SwiftUI

/// A script's library under the Latin families of a font picker: its heading ("Japanese fonts") and a chip per family, each
/// with a few letters of the script and its name, drawn in the family itself once it is here (in the system's face of the
/// script before). A family not downloaded yet shows a cloud; downloading, a ring that fills; a failed download, a sign that
/// a tap tries again. Tapping picks the family (it downloads the weight in use).
struct ScriptFontChips: View {
    let script: WritingScript
    let packs: [FontPack]
    let selection: TextOverlayFont?
    let weight: TextOverlayWeight
    let state: (FontPack) -> FontPackStore.State
    let identifier: String
    let onSelect: (FontPack) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 15
    @ScaledMetric(relativeTo: .subheadline) private var markSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(script.libraryTitle)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(packs) { pack in chip(pack) }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).library.\(script.rawValue)")
    }

    private func chip(_ pack: FontPack) -> some View {
        let face = TextOverlayFont.pack(pack.id)
        let isOn = face == selection
        let shown = state(pack)
        let label = "\(script.sample) \(pack.family)"
        let drawnWeight = pack.weights.contains(weight) ? weight : TextOverlayWeight.nearest(to: weight.value, in: pack.weights)
        return Button {
            Haptics.selection()
            onSelect(pack)
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: label)
                    .font(Font(TextFont.font(face, weight: drawnWeight, size: textSize, text: label)))
                    .lineLimit(1)
                    .fixedSize()
                mark(shown, isOn: isOn)
            }
            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 38)
            .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePress)
        .accessibilityLabel(Text(verbatim: pack.family))
        .accessibilityValue(Text(Self.stateDescription(shown)))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("\(identifier).pack.\(pack.id)")
    }

    @ViewBuilder
    private func mark(_ state: FontPackStore.State, isOn: Bool) -> some View {
        let ink = isOn ? Palette.chipOnInk : Palette.ink2
        switch state {
        case .ready:
            EmptyView()
        case .absent:
            Image(systemName: "icloud.and.arrow.down")
                .font(.editorGlyph(markSize * 0.86, weight: .semibold))
                .foregroundStyle(ink)
                .accessibilityHidden(true)
        case .downloading(let fraction):
            ZStack {
                Circle().stroke(ink.opacity(0.35), lineWidth: 2)
                Circle().trim(from: 0, to: max(0.04, fraction)).stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: markSize, height: markSize)
            .animation(.easeOut(duration: 0.2), value: fraction)
            .accessibilityHidden(true)
        case .failed:
            Image(systemName: "exclamationmark.arrow.circlepath")
                .font(.editorGlyph(markSize * 0.86, weight: .semibold))
                .foregroundStyle(isOn ? Palette.chipOnInk : Palette.warnText)
                .accessibilityHidden(true)
        }
    }

    static func stateDescription(_ state: FontPackStore.State) -> String {
        switch state {
        case .ready: String(localized: "Downloaded")
        case .absent: String(localized: "Downloads when you pick it")
        case .downloading(let fraction): String(localized: "Downloading, \(fraction.formatted(.percent.precision(.fractionLength(0))))")
        case .failed: String(localized: "Couldn’t download · tap to try again")
        }
    }
}
