//
//  FirstVoyageService.swift
//  Cue Studio
//

import Foundation

/// The first voyage: the guide that walks a new creator from their first script to their first video shared, in six steps (write,
/// practice, record, pick the best take, polish, share). No card: one tip at a time, the next step's, where it helps (above the dock on
/// Scripts, above the tab bar on Takes, and in the place each step happens), and a short notice when a step gets done
/// (`VoyageNotice`). The steps are read from what the creator has (`VoyageProgress`); this keeps only the voyage's own marks, on this
/// iPhone.
///
/// Only for creators who haven't shared a video yet: one who had (before the guide existed) never sees it. ✕ on a tip puts that step's
/// tip away for the session; it comes back next time while the step is still ahead. "Hide guide" puts the voyage away until Settings ›
/// Personalize brings it back, and the first video shared ends it.
@MainActor
@Observable
final class FirstVoyageService {
    private(set) var marks: VoyageMarks
    /// The steps whose tip was closed with ✕ this session.
    private(set) var closedThisSession: Set<VoyageStep> = []

    /// Where a measured moment goes (Analytics, only with "Help improve Cue" on; set by `AppServices`).
    @ObservationIgnored var report: (VoyageTelemetryEvent) -> Void = { _ in }

    private let library: ScriptLibraryService
    private let takes: TakeLibraryService
    private let milestones: MilestoneService
    private let defaults: UserDefaults
    /// UI tests leave the guide off unless they ask for it (`-uiTestVoyage`); nothing is saved then.
    private let isEnabled: Bool
    /// The tips already counted as shown this session, so a screen drawn again isn't counted twice.
    @ObservationIgnored private var shownThisSession: Set<String> = []

    init(
        library: ScriptLibraryService, takes: TakeLibraryService, milestones: MilestoneService, defaults: UserDefaults = .standard,
        isEnabled: Bool = true
    ) {
        self.library = library
        self.takes = takes
        self.milestones = milestones
        self.defaults = defaults
        self.isEnabled = isEnabled
        guard isEnabled else {
            marks = VoyageMarks(stage: .notNeeded)
            return
        }
        if let data = defaults.data(forKey: DefaultsKey.firstVoyage), let saved = try? JSONDecoder().decode(VoyageMarks.self, from: data) {
            marks = saved
        } else {
            // Decided once: a creator who has already shared a video doesn't need the way there.
            marks = VoyageMarks(stage: milestones.shares > 0 ? .notNeeded : .active)
            persist()
        }
    }

    // MARK: - Reading

    var progress: VoyageProgress {
        VoyageProgress(scripts: library.scripts.count, takes: takes.takes, shares: milestones.shares, marks: marks)
    }

    var isActive: Bool { marks.stage == .active }

    /// The step a tip is about shows its tip: it is next, and its tip wasn't closed this session.
    func showsTip(for step: VoyageStep) -> Bool {
        isActive && progress.current == step && !closedThisSession.contains(step)
    }

    /// The step whose tip shows above the dock (Scripts) or the tab bar (Takes), if any.
    var floatingStep: VoyageStep? {
        guard let step = progress.current, showsTip(for: step) else { return nil }
        return step
    }

    /// The tip on Cue's first draft, once: right after the first script Cue drafts, before the first take.
    func showsDraftTip(isCueDraft: Bool) -> Bool {
        guard isActive, isCueDraft, !marks.sawDraftTip, let current = progress.current else { return false }
        return current == .practice || current == .record
    }

    /// The steps done that haven't had their notice yet, in order.
    var stepsToAnnounce: [VoyageStep] {
        let done = progress.done
        return VoyageStep.allCases.filter { done.contains($0) && !marks.announced.contains($0) }
    }

    /// Settings › Personalize offers the guide while it can still help: on, or hidden.
    var canBeTurnedOn: Bool { marks.stage == .active || marks.stage == .hidden }

    // MARK: - Changing

    /// The teleprompter played a script.
    func markPracticed() {
        guard !marks.practiced else { return }
        update { $0.practiced = true }
    }

    /// "Skip" on Polish it.
    func skipPolish(at place: VoyageTipPlace) {
        report(.step(.polish, .acted, at: place))
        update { $0.skippedPolish = true }
    }

    /// A tip came into view (counted once per session and place).
    func tipShown(_ step: VoyageStep, at place: VoyageTipPlace) {
        guard isEnabled, shownThisSession.insert("\(step.rawValue).\(place.rawValue)").inserted else { return }
        report(.step(step, .shown, at: place))
    }

    /// A tip's button was tapped.
    func tipActed(_ step: VoyageStep, at place: VoyageTipPlace) {
        report(.step(step, .acted, at: place))
    }

    /// ✕ on a step's tip: away until the next session.
    func closeTip(_ step: VoyageStep, at place: VoyageTipPlace) {
        report(.step(step, .closed, at: place))
        closedThisSession.insert(step)
    }

    /// The first draft's tip came into view.
    func draftTipShown() {
        guard isEnabled, shownThisSession.insert("draft").inserted else { return }
        report(.draft(.shown))
    }

    /// The first draft's tip was read: "Edit" (`acted`) or ✕. It doesn't come back.
    func finishDraftTip(acted: Bool) {
        report(.draft(acted ? .acted : .closed))
        update { $0.sawDraftTip = true }
    }

    /// The notice for the steps done since the last one, and they are marked as said: the text to show, or nil. The first video shared
    /// ends the voyage.
    func takeNotice(hasCaptions: Bool) -> String? {
        let steps = stepsToAnnounce
        guard isActive, !steps.isEmpty else { return nil }
        let message = VoyageNotice.message(newlyDone: Set(steps), progress: progress, hasCaptions: hasCaptions)
        for step in steps { report(.step(step, .stepDone)) }
        update {
            $0.announced.formUnion(steps)
            if steps.contains(.share) { $0.stage = .finished }
        }
        return message
    }

    /// "Hide guide" (off), or Settings › Personalize bringing it back (on, with every tip back too).
    func setOn(_ isOn: Bool) {
        guard canBeTurnedOn else { return }
        if isOn { closedThisSession = [] }
        update { $0.stage = isOn ? .active : .hidden }
    }

    /// "Delete my Cue data": the voyage starts over (unless videos shared before stay counted).
    func reset() {
        guard isEnabled else { return }
        closedThisSession = []
        marks = VoyageMarks(stage: milestones.shares > 0 ? .notNeeded : .active)
        persist()
    }

    private func update(_ change: (inout VoyageMarks) -> Void) {
        guard isEnabled else { return }
        var next = marks
        change(&next)
        guard next != marks else { return }
        marks = next
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(marks), forKey: DefaultsKey.firstVoyage)
    }
}
