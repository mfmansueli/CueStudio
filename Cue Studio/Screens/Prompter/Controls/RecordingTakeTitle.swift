//
//  RecordingTakeTitle.swift
//  Cue Studio
//

import SwiftUI

/// What the Selfie navigation bar says about the take while it records, in the middle: "Take 4 · TikTok setup" ("Freestyle · Take 4" with no
/// script) and, when the platform has a minimum, the time left to it under it. A toolbar item in the system's type on Liquid Glass of its own
/// (the bar gives a middle item none), and it keeps its own size so nothing in it is ever cut.
struct RecordingTakeTitle: View {
    let viewModel: PrompterViewModel

    @Environment(TakeLibraryService.self) private var takes

    var body: some View {
        VStack(spacing: 1) {
            Text(subtitle)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
            if let chip = viewModel.monetizationChip {
                Text(chip)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.accText)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        // A middle toolbar item gets no glass from the bar, so it has its own, the same Liquid Glass as the chip at the end: without it the words
        // are lost over the picture.
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prompter.recordingTitle")
    }

    /// "Take 4 · TikTok setup" (or "Freestyle · Take 4" without a script).
    private var subtitle: String {
        let number = String(localized: "Take \(takes.nextNumber(for: viewModel.scriptID))")
        if viewModel.hasScript {
            return number + " · " + viewModel.session.captureSource.label
        }
        return String(localized: "Freestyle") + " · " + number
    }
}
