//
//  VoyageFloatingTip.swift
//  Cue Studio
//

import SwiftUI

/// The first voyage's next step on Scripts (10 pt above the dock) and Takes (above the tab bar): it waits 1.2 s after the screen settles
/// and shows only when nothing else is going on (`isQuiet`), like the My Cue Voice tip, which waits while this one has something to say.
/// Its button goes straight to where the step happens (`VoyageNavigator`); ✕ puts it away until the next session. It enters in 0.40 s
/// (opacity, 10 pt up) and leaves in 0.20 s; with Reduce Motion it only fades.
struct VoyageFloatingTip: View {
    let place: VoyageTipPlace
    /// Nothing else has the screen: no sheet, toast, keyboard, selection or other tab.
    let isQuiet: Bool

    @Environment(FirstVoyageService.self) private var voyage
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: VoyageStep?

    var body: some View {
        // A zero-height view always lives here: the task needs something to hang on while no tip is showing.
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if let step = shown {
                tip(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
                    .onAppear { voyage.tipShown(step, at: place) }
            }
        }
        .animation(shown == nil ? .easeOut(duration: 0.2) : (reduceMotion ? .easeOut(duration: 0.2) : CueMotion.tipEnter), value: shown)
        .task(id: Key(isQuiet: isQuiet, step: voyage.floatingStep)) { await evaluate() }
    }

    private struct Key: Hashable {
        let isQuiet: Bool
        let step: VoyageStep?
    }

    /// The step changed or was closed: the tip goes at once. A new one waits 1.2 s of quiet; one already up stays (a toast or a sheet
    /// passing over doesn't send it away).
    private func evaluate() async {
        guard let step = voyage.floatingStep else {
            shown = nil
            return
        }
        guard shown != step else { return }
        shown = nil
        guard isQuiet else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        guard !Task.isCancelled, isQuiet, voyage.floatingStep == step else { return }
        shown = step
    }

    private func tip(_ step: VoyageStep) -> some View {
        VoyageTipCard(
            step: step, symbol: step.symbol, title: step.tipTitle(network: navigator.videoTake?.platform?.label),
            message: step.tipMessage(duration: duration(for: step), network: navigator.videoTake?.platform?.label),
            primary: (step.tipAction(canCompare: navigator.canCompare), { act(step) }),
            onClose: { voyage.closeTip(step, at: place) }
        )
        .cardDepth(RoundedRectangle(cornerRadius: 20, style: .continuous), edge: nil)
    }

    private var navigator: VoyageNavigator {
        VoyageNavigator(library: library, takes: takes, presentation: presentation)
    }

    /// How long the script reads, for Practice ("0:44").
    private func duration(for step: VoyageStep) -> String? {
        guard step == .practice, let script = navigator.latestScript, !script.isEmpty else { return nil }
        return DurationText.clock(ReadTime.seconds(for: script.text))
    }

    private func act(_ step: VoyageStep) {
        voyage.tipActed(step, at: place)
        navigator.start(step)
    }
}
