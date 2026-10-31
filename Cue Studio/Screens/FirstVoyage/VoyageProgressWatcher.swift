//
//  VoyageProgressWatcher.swift
//  Cue Studio
//

import SwiftUI

/// Counts each step of the first voyage done (measured once, `FirstVoyageService.noteStepsDone`) and lets the first video shared end it.
/// It says nothing (owner, 30/10/2026): a step is shown done in its own tip, in place, and the send-off tells the first share. Lives once,
/// in `MainView`.
struct VoyageProgressWatcher: View {
    @Environment(FirstVoyageService.self) private var voyage

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: voyage.stepsToAnnounce, initial: true) { _, steps in
                if !steps.isEmpty { voyage.noteStepsDone() }
            }
    }
}
