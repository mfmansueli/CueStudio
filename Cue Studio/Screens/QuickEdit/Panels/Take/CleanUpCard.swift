//
//  CleanUpCard.swift
//  Cue Studio
//

import SwiftUI

/// A pause, filler word or possible retake in Pauses: how long, when, Remove or Keep, and Listen.
/// Tapping the card switches Remove and Keep.
struct CleanUpCard: View {
    let title: String
    let time: String
    let isMarked: Bool
    let isListening: Bool
    let identifier: String
    let onToggle: () -> Void
    let onListen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.title3, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Circle()
                    .fill(isMarked ? Palette.acc : Color.clear)
                    .overlay(Circle().strokeBorder(isMarked ? Palette.acc : Palette.ink2, lineWidth: 1.5))
                    .overlay {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Palette.accInk).opacity(isMarked ? 1 : 0)
                    }
                    .frame(width: 22, height: 22)
            }
            HStack {
                Text(time).font(.system(.caption).monospacedDigit()).foregroundStyle(Palette.ink2)
                Spacer(minLength: 4)
                Text(isMarked ? String(localized: "Remove") : String(localized: "Keep"))
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(isMarked ? Palette.accText : Palette.ink2)
            }
            Button(action: onListen) {
                HStack(spacing: 5) {
                    Image(systemName: "headphones").font(.system(size: 12, weight: .semibold))
                    Text(isListening ? String(localized: "Playing…") : String(localized: "Listen"))
                        .font(.system(.footnote, weight: .semibold))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(Palette.sliderTrack, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Listen"))
            .accessibilityIdentifier("\(identifier).listen")
        }
        .padding(10)
        .frame(width: 122)
        .background(isMarked ? Palette.accCard : Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isMarked ? Palette.acc : Color.clear, lineWidth: 1.5))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(title), \(time)"))
        .accessibilityValue(isMarked ? Text("Remove") : Text("Keep"))
        .accessibilityAction(named: Text(isMarked ? "Keep" : "Remove"), onToggle)
        .accessibilityIdentifier(identifier)
    }
}
