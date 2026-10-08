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

    var body: some View {
        SelfieControlSheet(parts: SelfieControlParts(viewModel: viewModel, session: session, audio: audio), isOut: $isOut)
    }
}
