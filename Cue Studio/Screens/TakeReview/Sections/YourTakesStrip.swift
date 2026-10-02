//
//  YourTakesStrip.swift
//  Cue Studio
//

import SwiftUI

/// "Your takes · 3": every take of the script, to switch between them and pick the best, then
/// "Suggest best".
struct YourTakesStrip: View {
    let takes: [Take]
    let currentID: UUID
    /// Nil hides "Suggest best".
    var onSuggest: (() -> Void)?
    let onSelect: (Take) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your takes · \(takes.count)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                Spacer()
                Text("Tap ☆ to pick your best")
                    .font(.caption)
            }
            .foregroundStyle(Palette.ink2)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(takes) { take in
                        tile(take)
                    }
                    if let onSuggest { suggestTile(action: onSuggest) }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Metrics.gutter)
        }
    }

    private func suggestTile(action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Palette.accText)
                Text("Suggest best").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(height: 60)
            .background(Palette.stripTile, in: shape)
            .overlay(shape.strokeBorder(Palette.accBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review.suggestBestButton")
    }

    private func tile(_ take: Take) -> some View {
        let isCurrent = take.id == currentID
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { onSelect(take) } label: {
            HStack(spacing: 9) {
                TakeThumbnail(take: take)
                    .frame(width: 27, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(take.label).font(.subheadline.weight(.semibold))
                        if take.isBest {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(Palette.accText)
                        }
                    }
                    Text(DurationText.short(take.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.ink2)
                }
                .foregroundStyle(Palette.ink)
            }
            .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 12))
            .frame(height: 60)
            .background(Palette.stripTile, in: shape)
            .overlay(shape.strokeBorder(isCurrent ? Palette.acc : .clear, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityLabel(Text(take.isBest ? "\(take.label), best take" : take.label))
        .accessibilityIdentifier("review.strip.\(take.number)")
    }
}
