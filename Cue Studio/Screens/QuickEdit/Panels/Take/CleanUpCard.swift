//
//  CleanUpCard.swift
//  Cue Studio
//

import SwiftUI

/// A pause, filler word or possible retake in Pauses: how long and Remove or Keep on top, when and Listen under it. Tapping
/// the card switches Remove and Keep; the marked one is outlined in yellow. Two lines, so the whole card shows in the panel
/// with the length stepper above it, even on an iPhone SE.
struct CleanUpCard: View {
    let title: String
    let time: String
    let isMarked: Bool
    let isListening: Bool
    let identifier: String
    var width: CGFloat = 122
    let onToggle: () -> Void
    let onListen: () -> Void

    /// The Listen circle; its touch target is the full 44 pt around it.
    @ScaledMetric(relativeTo: .footnote) private var listenSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.system(.title3, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Text(isMarked ? String(localized: "Remove") : String(localized: "Keep"))
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(isMarked ? Palette.accText : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            HStack(alignment: .center, spacing: 4) {
                Text(time)
                    .font(.system(.caption).monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                listenButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: width, alignment: .leading)
        .editorCard(isMarked ? .marked : .plain)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(title), \(time)"))
        .accessibilityValue(isMarked ? Text("Remove") : Text("Keep"))
        .accessibilityAction(named: Text(isMarked ? "Keep" : "Remove"), onToggle)
        .accessibilityIdentifier(identifier)
    }

    /// Plays the take around this moment without it; a speaker while it plays.
    private var listenButton: some View {
        let inset = max(0, (Metrics.hitTarget - listenSize) / 2)
        return Button(action: onListen) {
            Image(systemName: isListening ? "speaker.wave.2.fill" : "headphones")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(isListening ? Palette.accInk : Palette.ink)
                .frame(width: listenSize, height: listenSize)
                .background(isListening ? Palette.acc : Palette.Slider.track, in: Circle())
                .contentTransition(.symbolEffect(.replace))
                // A 44 pt target without making the line taller.
                .padding(inset)
                .contentShape(Rectangle())
                .padding(-inset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Listen"))
        .accessibilityValue(isListening ? Text("Playing…") : Text(""))
        .accessibilityIdentifier("\(identifier).listen")
    }
}
