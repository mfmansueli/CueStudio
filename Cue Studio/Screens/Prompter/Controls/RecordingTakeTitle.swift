//
//  RecordingTakeTitle.swift
//  Cue Studio
//

import SwiftUI

/// What the Selfie navigation bar says about the take while it records, beside the REC pill: "Take 4" ("Freestyle · Take 4" with no script)
/// and, when the platform has a minimum, the time left to it under it. The setup and the network stay off the bar while recording (owner,
/// 11/11/2026: too much at once). On Liquid Glass of its own, the REC pill's neighbour; where the bar has little room (`RecordingBarLayout`)
/// the words shrink a little rather than run under the clock.
struct RecordingTakeTitle: View {
    let viewModel: PrompterViewModel

    @Environment(TakeLibraryService.self) private var takes

    var body: some View {
        VStack(spacing: 1) {
            Text(subtitle)
                .cueFont(.footnote, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(Self.smallestScale)
            if let chip = viewModel.monetizationChip {
                Text(chip)
                    .cueFont(.caption2, weight: .semibold)
                    .foregroundStyle(Palette.accText)
                    .lineLimit(1)
                    .minimumScaleFactor(Self.smallestScale)
            }
        }
        // The recording item hides the bar's shared glass (the REC pill is red), so this has its own: without it the words are lost over the
        // picture.
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prompter.recordingTitle")
    }

    /// How small the words may get before they are cut, on the narrowest bar.
    private static let smallestScale: CGFloat = 0.75

    /// "Take 4" (or "Freestyle · Take 4" without a script).
    private var subtitle: String {
        let number = String(localized: "Take \(takes.nextNumber(for: viewModel.scriptID))")
        guard viewModel.hasScript else { return String(localized: "Freestyle") + " · " + number }
        return number
    }
}
