//
//  SoundEffectCell.swift
//  Cue Studio
//

import SwiftUI

/// One sound effect: its name and what it's for (tap to hear it; while it plays its icon says so and a second tap stops it), and
/// a separate + that adds it at the playhead, as tall as the row's tallest.
struct SoundEffectCell: View {
    let viewModel: QuickEditViewModel
    let effect: SoundEffect
    let onAdded: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var isPlaying: Bool { viewModel.audio.soundPreviews.playingKey == effect.rawValue }
    /// Beside a neighbour the name keeps to one line while it fits, else two broken between words (never "Heart-beat" split in two),
    /// a little smaller only past that (`WholeWordsLabel`); what it's for takes the lines it needs. Never cut (owner, 02/11/2026:
    /// "Rufar de t…", "Toque dra…").

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if isPlaying { viewModel.audio.soundPreviews.stop() } else { viewModel.audio.soundPreviews.play(effect) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : effect.systemImage)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(isPlaying ? Palette.accText : Palette.ink)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .frame(minWidth: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Group {
                            if typeSize.isAccessibilitySize {
                                Text(effect.label)
                            } else {
                                WholeWordsLabel(text: effect.label, alignment: .leading, minimumScale: Self.nameMinimumScale)
                            }
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        Text(effect.use)
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isPlaying ? "Stop \(effect.label)" : "Hear \(effect.label)"))
            .accessibilityIdentifier("edit.effect.play.\(effect.rawValue)")
            Button {
                viewModel.audio.soundPreviews.stop()
                viewModel.audio.addSoundEffect(effect)
                onAdded()
            } label: {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: Metrics.hitTarget)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Add \(effect.label)"))
            .accessibilityIdentifier("edit.effect.add.\(effect.rawValue)")
        }
        .foregroundStyle(Palette.ink)
        .frame(maxHeight: .infinity)
        .editorCard(isPlaying ? .picked : .plain)
    }

    private static let nameMinimumScale: CGFloat = 0.85

    /// Whether `name` reads whole in a cell `cellWidth` wide: on one line or on two broken between words (`LabelLineBreak`), at most a
    /// little smaller, in the room the cell leaves it (its padding, the icon and the + button).
    static func nameFits(_ name: String, cellWidth: CGFloat, typeSize: DynamicTypeSize) -> Bool {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        let size = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).pointSize
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        let width: (String) -> CGFloat = { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }
        let lines = LabelLineBreak.twoLines(name)?.components(separatedBy: "\n") ?? [name]
        let needed = min(width(name), lines.map(width).max() ?? 0) * nameMinimumScale
        // The leading padding, the icon (2 pt to spare for a wider one, ♩♩), the row's spacing on both sides of the name (the
        // spacer after it counts too) and the + button.
        return needed <= cellWidth - 12 - 22 - 10 - 10 - Metrics.hitTarget
    }
}
