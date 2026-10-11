//
//  VoyageAnnouncer.swift
//  Cue Studio
//

import SwiftUI

/// Says when a step of the first voyage gets done, as a toast ("✓ Recorded · Next: pick a take"): once the creator is back from the
/// camera and the review (nothing is said over the teleprompter while they read), when no other toast is showing, with a soft tap.
/// The first video shared says "✓ Your first star is out there" and ends the voyage. Lives once, in `MainView`.
struct VoyageAnnouncer: View {
    @Environment(FirstVoyageService.self) private var voyage
    @Environment(PresentationService.self) private var presentation
    @Environment(TakeLibraryService.self) private var takes
    @Environment(ToastService.self) private var toast

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: Key(steps: voyage.stepsToAnnounce, isFree: isFree)) { await announce() }
    }

    private struct Key: Hashable {
        let steps: [VoyageStep]
        let isFree: Bool
    }

    /// Out of the camera and the review, and no toast on screen.
    private var isFree: Bool {
        presentation.prompter == nil && toast.message == nil
    }

    private func announce() async {
        guard isFree, voyage.isActive, !voyage.stepsToAnnounce.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled, isFree else { return }
        let hasCaptions = takes.takes.contains { !($0.edit?.captions.isEmpty ?? true) }
        guard let message = voyage.takeNotice(hasCaptions: hasCaptions) else { return }
        Haptics.soft()
        toast.show(message)
    }
}
