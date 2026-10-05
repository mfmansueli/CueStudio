//
//  VoiceQuestionTipHost.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// Where the My Cue Voice tip shows (Scripts above the dock, Takes above the tab bar): it waits 1.2 s after the screen settles and
/// shows only when nothing else is going on (`isQuiet`), then the scheduler's question comes as a tip. Tapping it opens the question
/// sheet; its ✕ is a dismissal (the question waits three days). It enters in 0.40 s (opacity, 10 pt up, 0.97 → 1) and leaves in 0.20 s;
/// with Reduce Motion it only fades.
struct VoiceQuestionTipHost: View {
    /// Nothing else has the screen: no sheet, toast, keyboard, scrolling or open dock.
    let isQuiet: Bool

    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(AIStatus.self) private var aiStatus
    @Environment(ToastService.self) private var toast
    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: VoiceQuestion?
    @State private var tip: VoiceQuestionTip?
    @State private var sheetQuestion: VoiceQuestion?

    var body: some View {
        // A zero-height view always lives here: the tasks need something to hang on while no tip is showing.
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if let tip, shown != nil {
                TipView(tip)
                    .tipViewStyle(VoiceTipViewStyle(onOpen: open))
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("voice.tip")
            }
        }
        .animation(shown == nil ? .easeOut(duration: 0.2) : (reduceMotion ? .easeOut(duration: 0.2) : CueMotion.tipEnter), value: shown)
        .task(id: EvaluationKey(isQuiet: isQuiet, strength: profile.profile.voiceStrength, scripts: library.scripts.count, ai: aiStatus.isAvailable)) {
            await evaluate()
        }
        .task(id: tip?.id) { await watchClose() }
        .sheet(item: $sheetQuestion) { question in
            VoiceQuestionSheet(model: VoiceQuestionSheetModel(
                question: question, mode: .tip, profile: profile, scheduler: scheduler, toast: toast
            ))
        }
    }

    private struct EvaluationKey: Hashable {
        let isQuiet: Bool
        let strength: Int
        let scripts: Int
        let ai: Bool
    }

    /// 1.2 s after the screen settles, if it is quiet: ask the scheduler. A tip already up stays until it is dealt with.
    private func evaluate() async {
        guard shown == nil, sheetQuestion == nil, isQuiet else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 1200 : 1200))
        noteMoments()
        guard !Task.isCancelled, isQuiet,
              let question = scheduler.tipQuestion(isAIAvailable: aiStatus.isAvailable, scriptCount: library.scripts.count) else { return }
        tip = VoiceQuestionTip(
            question: question, round: scheduler.state.dismissCount[question.rawValue, default: 0], strength: profile.profile.voiceStrength
        )
        shown = question
        scheduler.tipShown()
    }

    /// The moments that ask a question sooner (08 §3): the first export (where they post), the third script recorded (an example).
    private func noteMoments() {
        if takes.takes.contains(where: \.isExported) { scheduler.note(.firstExport) }
        if Set(takes.takes.compactMap(\.scriptID)).count >= 3 { scheduler.note(.thirdScriptRecorded) }
    }

    /// The tip's ✕ (TipKit invalidates it): a dismissal.
    private func watchClose() async {
        guard let tip, let question = shown else { return }
        for await status in tip.statusUpdates {
            if case .invalidated(let reason) = status, reason == .tipClosed {
                scheduler.dismissed(question)
                shown = nil
                return
            }
        }
    }

    private func open() {
        guard let question = shown, let tip else { return }
        tip.invalidate(reason: .actionPerformed)
        shown = nil
        sheetQuestion = question
    }
}
