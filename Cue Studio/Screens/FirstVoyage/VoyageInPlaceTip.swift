//
//  VoyageInPlaceTip.swift
//  Cue Studio
//

import SwiftUI

/// A first voyage tip in the place its step happens (Practice on the page, Pick in the review, Polish in the editor, Share in the networks'
/// sheet): it shows while its step is the next one and the place allows it. When the step gets done while it is on screen, the same tip
/// says so (the disc turns into a ✓, the eyebrow reads "· DONE") for a moment and goes; no toast. A tip seen here doesn't float on
/// Scripts or Takes again this session (`FirstVoyageService.tipShown`).
struct VoyageInPlaceTip<Card: View>: View {
    let step: VoyageStep
    let place: VoyageTipPlace
    /// The place's own conditions (not over a story, a panel or the editor).
    let isAllowed: Bool
    /// The tip, done or not.
    @ViewBuilder let card: (_ isDone: Bool) -> Card

    @Environment(FirstVoyageService.self) private var voyage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDone = false

    /// How long the done tip stays before it goes.
    static var doneHold: Duration { .milliseconds(1400) }

    private var isVisible: Bool { isAllowed && voyage.showsTip(for: step) }

    private struct Moment: Equatable {
        let isVisible: Bool
        let isDone: Bool
    }

    var body: some View {
        Group {
            if showsDone {
                card(true)
                    .transition(.opacity)
            } else if isVisible {
                card(false)
                    .transition(.opacity)
                    .onAppear { voyage.tipShown(step, at: place) }
            }
        }
        // Read together, so "it was on screen" and "now it's done" are the same change.
        .onChange(of: Moment(isVisible: isVisible, isDone: voyage.progress.done.contains(step))) { old, new in
            guard old.isVisible, !old.isDone, new.isDone else { return }
            showsDone = true
            AccessibilityNotification.Announcement(String(localized: "Step \(step.number) done")).post()
            Task {
                try? await Task.sleep(for: Self.doneHold)
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.3)) { showsDone = false }
            }
        }
    }
}
