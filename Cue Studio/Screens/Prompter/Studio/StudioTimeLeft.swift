//
//  StudioTimeLeft.swift
//  Cue Studio
//

import SwiftUI

/// "0:42 LEFT" in Studio's time line: the only part that reads the scroll progress, so only it redraws with every frame of the text.
struct StudioTimeLeft: View {
    let viewModel: PrompterViewModel
    /// The whole script's seconds at the set speed.
    let total: TimeInterval

    var body: some View {
        Text("\(DurationText.clock(total * (1 - viewModel.engine.progress))) LEFT")
            .foregroundStyle(Palette.accText)
            .accessibilityIdentifier("studio.timeLeft")
    }
}
