//
//  VoiceChoiceRow.swift
//  Cue Studio
//

import SwiftUI

/// One row of a list of choices in the voice editor: the name (and a line under it), and the round marker at the end: a dot when only one can
/// be chosen, a check when several can.
struct VoiceChoiceRow: View {
    let title: String
    var detail: String?
    var tag: String?
    let isOn: Bool
    var isCheck = false
    var isDimmed = false
    var identifier: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    // The note goes beside the name when it fits, and under it when it doesn't (never cut off).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { name }
                        VStack(alignment: .leading, spacing: 2) { name }
                    }
                    if let detail {
                        Text(detail).font(.footnote).italic().foregroundStyle(Palette.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VoiceRadio(isOn: isOn, isCheck: isCheck)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .opacity(isOn || !isDimmed ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var name: some View {
        Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
        if let tag {
            Text(tag).font(.caption2.weight(.semibold)).foregroundStyle(Palette.accText).lineLimit(1)
        }
    }
}
