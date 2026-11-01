//
//  VoyageFloatingTip.swift
//  Cue Studio
//

import SwiftUI

/// The first voyage's next step on Scripts (10 pt above the dock) and Takes (above the tab bar): it waits 1.2 s after the screen settles
/// and shows only when nothing else is going on (`isQuiet`) and nothing else has the place (`GuidanceGate`: the creator's queue left
/// waiting goes first; a My Cue Voice question and the Ultra AI line wait while it has something to say). A step already seen in its own
/// place this session doesn't float (`FirstVoyageService.floatingStep`). VoiceOver hears it arrive. Its button goes straight to where the
/// step happens (`VoyageNavigator`); ✕ puts it away until the next session, and nothing else comes in its place. It enters in 0.40 s
/// (opacity, 10 pt up) and leaves in 0.20 s; with Reduce Motion it only fades.
struct VoyageFloatingTip: View {
    let place: VoyageTipPlace
    /// Nothing else has the screen: no sheet, toast, keyboard, selection or other tab.
    let isQuiet: Bool

    @Environment(FirstVoyageService.self) private var voyage
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(GuidanceGate.self) private var guidance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: VoyageStep?

    private var gatePlace: GuidancePlace { place.guidancePlace ?? .scripts }

    private var mayShow: Bool { guidance.mayShow(.voyageTip, at: gatePlace) }

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
                    .onAppear { arrived(step) }
            }
        }
        .animation(shown == nil ? .easeOut(duration: 0.2) : (reduceMotion ? .easeOut(duration: 0.2) : CueMotion.tipEnter), value: shown)
        .task(id: Key(isQuiet: isQuiet, mayShow: mayShow, step: voyage.floatingStep)) { await evaluate() }
        // Due: what comes after it on this screen waits.
        .onChange(of: voyage.floatingStep, initial: true) { _, step in
            guidance.setWaiting(.voyageTip, at: gatePlace, step != nil)
        }
        .onDisappear { guidance.setWaiting(.voyageTip, at: gatePlace, false) }
    }

    private struct Key: Hashable {
        let isQuiet: Bool
        let mayShow: Bool
        let step: VoyageStep?
    }

    /// The step changed or was closed: the tip goes at once. A new one waits 1.2 s of quiet; one already up stays (a toast or a sheet
    /// passing over doesn't send it away), unless the creator's own queue takes the place.
    private func evaluate() async {
        guard let step = voyage.floatingStep, mayShow else {
            leave()
            return
        }
        guard shown != step else { return }
        leave()
        guard isQuiet else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        guard !Task.isCancelled, isQuiet, mayShow, voyage.floatingStep == step else { return }
        shown = step
        guidance.shown(.voyageTip, at: gatePlace)
    }

    private func leave(closed: Bool = false) {
        guard shown != nil else { return }
        shown = nil
        guidance.left(.voyageTip, at: gatePlace, closed: closed)
    }

    private func arrived(_ step: VoyageStep) {
        voyage.tipShown(step, at: place)
        let title = step.tipTitle(network: navigator.videoTake?.platform?.label)
        AccessibilityNotification.Announcement(String(localized: "Tip: \(title)")).post()
    }

    private func tip(_ step: VoyageStep) -> some View {
        VoyageTipCard(
            step: step, title: step.tipTitle(network: navigator.videoTake?.platform?.label),
            message: step.tipMessage(duration: duration(for: step), network: navigator.videoTake?.platform?.label),
            primary: (step.tipAction(canCompare: navigator.canCompare), { act(step) }),
            onClose: {
                voyage.closeTip(step, at: place)
                leave(closed: true)
            }
        )
    }

    private var navigator: VoyageNavigator {
        VoyageNavigator(library: library, takes: takes, presentation: presentation)
    }

    /// How long the script reads, for Practice ("0:44").
    private func duration(for step: VoyageStep) -> String? {
        guard step == .practice, let script = navigator.latestScript, !script.isEmpty else { return nil }
        return DurationText.clock(script.readSeconds)
    }

    private func act(_ step: VoyageStep) {
        voyage.tipActed(step, at: place)
        navigator.start(step)
    }
}
