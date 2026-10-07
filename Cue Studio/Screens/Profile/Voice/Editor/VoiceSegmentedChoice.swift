//
//  VoiceSegmentedChoice.swift
//  Cue Studio
//

import SwiftUI

/// A short row of exclusive choices ("Calm · Balanced · High"): the chosen one in yellow. Tapping the chosen one again lets it go when `allowsNone`.
struct VoiceSegmentedChoice<Value: Hashable & Identifiable>: View {
    let values: [Value]
    let selection: Value?
    let label: (Value) -> String
    let onPick: (Value) -> Void
    /// Accessibility identifier prefix: `<prefix>.<value id>`.
    let identifier: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(values) { value in
                let picked = selection == value
                Button {
                    Haptics.selection()
                    onPick(value)
                } label: {
                    Text(label(value))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(picked ? Palette.accInk : Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                        .background(picked ? Palette.chipOn : Palette.fill, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
                .accessibilityIdentifier("\(identifier).\(value.id)")
            }
        }
    }
}
