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
    /// Beside a neighbour the name keeps to one line, a little smaller if it must (never "Heart-beat" split in two), and what it's for
    /// to two; alone in its row at the accessibility sizes, both take the lines they need.
    private var nameLines: Int? { typeSize.isAccessibilitySize ? nil : 1 }
    private var useLines: Int? { typeSize.isAccessibilitySize ? nil : 2 }

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
                        Text(effect.label)
                            .font(.system(.subheadline, weight: .semibold))
                            .lineLimit(nameLines)
                            .minimumScaleFactor(0.8)
                        Text(effect.use)
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(useLines)
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
}
