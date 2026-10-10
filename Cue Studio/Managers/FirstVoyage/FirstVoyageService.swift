//
//  FirstVoyageService.swift
//  Cue Studio
//

import Foundation

/// The first voyage: the guide that walks a new creator from their first script to their first video shared, in six steps (write,
/// practice, record, pick the best take, polish, share). The card on Scripts and Takes names the next step, one tip at a time shows
/// in the place each step happens, and the card lights a segment for every step done. The steps are read from what the creator has
/// (`VoyageProgress`); this keeps only the voyage's own marks, on this iPhone.
///
/// Only for creators who haven't shared a video yet: one who had (before the guide existed) never sees it. "Hide guide" puts it away
/// until Settings › Personalize brings it back; once the first video is shared the card says the voyage is complete, and closing it
/// ends the voyage for good.
@MainActor
@Observable
final class FirstVoyageService {
    private(set) var marks: VoyageMarks

    private let library: ScriptLibraryService
    private let takes: TakeLibraryService
    private let milestones: MilestoneService
    private let defaults: UserDefaults
    /// UI tests leave the guide off unless they ask for it (`-uiTestVoyage`); nothing is saved then.
    private let isEnabled: Bool

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

    /// The card shows: the next step, or that the voyage is complete.
    var showsCard: Bool { marks.stage == .active }

    /// The step a tip is about shows its tip: it is next, and its tip wasn't closed.
    func showsTip(for step: VoyageStep) -> Bool {
        marks.stage == .active && progress.current == step && !marks.closedTips.contains(step)
    }

    /// The steps done since the card last lit them up, in order.
    var stepsToCelebrate: [VoyageStep] {
        let done = progress.done
        return VoyageStep.allCases.filter { done.contains($0) && !marks.celebrated.contains($0) }
    }

    /// Settings › Personalize offers the guide while it can still help: on, or hidden.
    var canBeTurnedOn: Bool { marks.stage == .active || marks.stage == .hidden }

    // MARK: - Changing

    /// The teleprompter played a script.
    func markPracticed() {
        guard !marks.practiced else { return }
        update { $0.practiced = true }
    }

    /// "Skip this step" on Polish it.
    func skipPolish() {
        update {
            $0.skippedPolish = true
            $0.closedTips.insert(.polish)
        }
    }

    /// ✕ on a step's tip: it doesn't come back.
    func closeTip(_ step: VoyageStep) {
        update { $0.closedTips.insert(step) }
    }

    /// The card lit these segments up.
    func markCelebrated(_ steps: [VoyageStep]) {
        guard !steps.isEmpty else { return }
        update { $0.celebrated.formUnion(steps) }
    }

    /// "Hide guide" (off), or Settings › Personalize bringing it back (on).
    func setOn(_ isOn: Bool) {
        guard canBeTurnedOn else { return }
        update { $0.stage = isOn ? .active : .hidden }
    }

    /// The completed card was closed: the voyage is over.
    func finish() {
        update { $0.stage = .finished }
    }

    /// "Delete my Cue data": the voyage starts over (unless videos shared before stay counted).
    func reset() {
        guard isEnabled else { return }
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
