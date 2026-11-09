//
//  SelfieControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// The toolbar of Selfie, in night glass: one sheet (`SelfieControlSheet`) with what it takes to record always in it and the reading controls
/// folded into it above, which the chevron brings out. While a take records it gathers into one row. The controls themselves are
/// `SelfieControlParts`.
struct SelfieControlPanel: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio

    /// The reading controls are out of the sheet (they start that way). Kept here so it survives a take.
    @State private var isOut = true
    /// The reading controls folded themselves to make room for the recommendation card, and come back out once it is answered.
    @State private var foldedForRecommendation = false

    var body: some View {
        SelfieControlSheet(parts: SelfieControlParts(viewModel: viewModel, session: session, audio: audio), isOut: $isOut)
            // The card sits just above the sheet: with the reading controls folded it stays clear of the text window.
            .onChange(of: viewModel.showsRecommendation, initial: true) { _, shows in
                if shows, isOut {
                    foldedForRecommendation = true
                    isOut = false
                } else if !shows, foldedForRecommendation {
                    foldedForRecommendation = false
                    isOut = true
                }
            }
    }
}
