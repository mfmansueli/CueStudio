//
//  VoiceOptionChips.swift
//  Cue Studio
//

import SwiftUI

/// The answers of a question as chips that wrap: one tap puts one in or takes it out. Everything the editor offers as a handful of words (formats,
/// openings, endings, what to avoid, platforms, why they watch, what the videos are for) is one of these.
struct VoiceOptionChips: View {
    let options: [VoiceOption]
    let isSelected: (VoiceOption) -> Bool
    let onTap: (VoiceOption) -> Void
    /// What the creator typed that isn't one of the options: shown after them, selected.
    var extras: [String] = []
    var onTapExtra: (String) -> Void = { _ in }
    /// Accessibility identifier prefix: `<prefix>.<option id>`.
    var identifier = "voice.option"

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 4) {
            ForEach(options) { option in
                let isOn = isSelected(option)
                Button {
                    Haptics.selection()
                    onTap(option)
                } label: {
                    FilterChip(label: option.label, isSelected: isOn)
                        .frame(minHeight: Metrics.hitTarget)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifier).\(option.id)")
            }
            ForEach(extras, id: \.self) { value in
                Button {
                    Haptics.selection()
                    onTapExtra(value)
                } label: {
                    FilterChip(label: value, isSelected: true)
                        .frame(minHeight: Metrics.hitTarget)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifier).typed")
            }
        }
    }
}
