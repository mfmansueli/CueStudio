//
//  VoiceQuestionTipHost.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// Where the My Cue Voice tip shows (Scripts above the dock, Takes above the tab bar): it waits 1.2 s after the screen settles and
/// shows only when nothing else is going on (`isQuiet`) and nothing else has the place (`GuidanceGate`), then the scheduler's question
/// comes as a tip. It counts as shown only once TipKit makes it visible (`.available`), and VoiceOver hears it arrive. Tapping it opens
/// the question sheet; its ✕ is a dismissal (the question waits three days, and nothing else comes on this screen this session). It
/// enters in 0.40 s (opacity, 10 pt up, 0.97 → 1) and leaves in 0.20 s; with Reduce Motion it only fades.
struct VoiceQuestionTipHost: View {
    let place: GuidancePlace
    /// Nothing else has the screen: no sheet, toast, keyboard, scrolling or open dock.
    let isQuiet: Bool

    @Environment(VoiceQuestionScheduler.self) private var scheduler
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(AIStatus.self) private var aiStatus
    @Environment(ToastService.self) private var toast
    @Environment(TakeLibraryService.self) private var takes
    @Environment(GuidanceGate.self) private var guidance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: VoiceQuestion?
    @State private var tip: VoiceQuestionTip?
    @State private var sheetQuestion: VoiceQuestion?
    /// TipKit made the tip visible (`.available`): only then is a ✕ a dismissal and the day used.
    @State private var isVisible = false

    private var mayShow: Bool { guidance.mayShow(.voiceTip, at: place) }

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
        .task(id: EvaluationKey(
            isQuiet: isQuiet && mayShow, strength: profile.profile.voiceStrength, scripts: library.scripts.count, ai: aiStatus.isAvailable
        )) {
            await evaluate()
        }
        .task(id: tip?.id) { await watchStatus() }
        .onChange(of: mayShow) { _, may in
            // The creator's own work left waiting takes the place: the tip steps aside, unspent.
            if !may, shown != nil { withdraw() }
        }
        .sheet(item: $sheetQuestion) { question in
            VoiceQuestionSheet(model: VoiceQuestionSheetModel(
                question: question, profile: profile, scheduler: scheduler, toast: toast
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
        guard shown == nil, sheetQuestion == nil, isQuiet, mayShow else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        noteMoments()
        guard !Task.isCancelled, isQuiet, mayShow,
              let question = scheduler.tipQuestion(isAIAvailable: aiStatus.isAvailable, scriptCount: library.scripts.count) else { return }
        tip = VoiceQuestionTip(question: question, tipID: scheduler.tipID(for: question), strength: profile.profile.voiceStrength)
        isVisible = false
        shown = question
        guidance.shown(.voiceTip, at: place)
    }

    /// The moments that ask a question sooner (08 §3): the first export (where they post), the third script recorded (an example).
    private func noteMoments() {
        if takes.takes.contains(where: \.isExported) { scheduler.note(.firstExport) }
        if Set(takes.takes.compactMap(\.scriptID)).count >= 3 { scheduler.note(.thirdScriptRecorded) }
    }

    /// What TipKit says of the tip: visible (counted, and said to VoiceOver), closed with ✕ (a dismissal, only if it was visible), or
    /// invalidated before it ever showed (put away, nothing counted).
    private func watchStatus() async {
        guard let tip, let question = shown else { return }
        for await status in tip.statusUpdates {
            switch status {
            case .available:
                guard !isVisible else { continue }
                isVisible = true
                scheduler.tipShown()
                AccessibilityNotification.Announcement(String(localized: "Tip: \(question.title)")).post()
            case .invalidated(let reason):
                scheduler.tipSpent(question)
                if reason == .tipClosed, isVisible {
                    scheduler.dismissed(question)
                    guidance.left(.voiceTip, at: place, closed: true)
                } else if reason != .actionPerformed {
                    guidance.left(.voiceTip, at: place)
                }
                if reason != .actionPerformed { shown = nil }
                return
            default:
                continue
            }
        }
    }

    private func open() {
        guard let question = shown, let tip else { return }
        tip.invalidate(reason: .actionPerformed)
        shown = nil
        guidance.left(.voiceTip, at: place)
        sheetQuestion = question
    }

    /// Off screen without being spent: it can come back later.
    private func withdraw() {
        shown = nil
        tip = nil
        guidance.left(.voiceTip, at: place)
    }
}
