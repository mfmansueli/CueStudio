//
//  CleanUpRetakeCard.swift
//  Cue Studio
//

import SwiftUI

/// A script line said more than once: "Said 3 times", the line, and each try with Listen (it plays alone) and Keep this one
/// (the others are marked to go). Nothing is picked for the creator.
struct CleanUpRetakeCard: View {
    @Bindable var viewModel: QuickEditViewModel
    let group: CleanUpRetakeGroup
    let identifier: String

    var body: some View {
        let clips = viewModel.clips
        VStack(alignment: .leading, spacing: 6) {
            Text("Said \(group.tries.count) times", comment: "Clean up › Words: a script line was said this many times")
                .cueFont(.caption, weight: .semibold)
                .foregroundStyle(Palette.ink2)
            Text(verbatim: "“\(group.line)”")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(group.tries.enumerated()), id: \.element.id) { index, attempt in
                row(attempt, isKept: clips.isKeptTry(attempt, in: group), identifier: "\(identifier).try.\(index)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func row(_ attempt: CleanUpSuggestion, isKept: Bool, identifier: String) -> some View {
        let clips = viewModel.clips
        let isMarked = clips.isMarked(attempt)
        let isListening = clips.listeningID == attempt.id
        return HStack(spacing: 8) {
            Button { clips.listenToTry(attempt.id) } label: {
                Image(systemName: isListening ? "speaker.wave.2.fill" : "headphones")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(isListening ? Palette.accInk : Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(isListening ? Palette.acc : Palette.Slider.track, in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Listen to \(clips.tryLabel(attempt))"))
            .accessibilityIdentifier("\(identifier).listen")
            VStack(alignment: .leading, spacing: 1) {
                Text(clips.tryLabel(attempt)).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                Text(isMarked ? String(localized: "Remove") : (isKept ? String(localized: "Kept") : clips.cardTime(attempt)))
                    .cueFont(.caption)
                    .monospacedDigit()
                    .foregroundStyle(isMarked ? Palette.accText : Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            PanelButton(
                label: isKept ? String(localized: "Kept") : String(localized: "Keep this one"),
                systemImage: isKept ? "checkmark" : nil, isCompact: true, identifier: "\(identifier).keep"
            ) { clips.keepTry(attempt.id, in: group) }
        }
    }
}
