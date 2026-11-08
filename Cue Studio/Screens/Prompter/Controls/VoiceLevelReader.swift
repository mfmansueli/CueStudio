//
//  VoiceLevelReader.swift
//  Cue Studio
//

import SwiftUI

/// Hands the microphone's level to a meter, reading it in its own small body: the level changes 20 times a second while Voice Following
/// listens, and read by a panel or a sheet it redrew all of it each time.
struct VoiceLevelReader<Content: View>: View {
    let viewModel: PrompterViewModel
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        content(viewModel.voiceLevel)
    }
}
