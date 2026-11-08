//
//  AutoEditSession.swift
//  Cue Studio
//

import Foundation

/// Auto edit while its sheet is open (`QuickEditViewModel+AutoEdit`): what the creator picked, where the run is, and what it did.
@MainActor
@Observable
final class AutoEditSession {
    enum Phase: Equatable {
        /// Picking the steps; nothing changed yet.
        case choosing
        /// Running; Cancel leaves the edit as it was.
        case working(Stage)
        /// Done: what each step did, to compare or turn off.
        case done
    }

    enum Stage: Equatable {
        case listening, captions, applying
    }

    var phase: Phase = .choosing
    /// The steps that run.
    var steps: Set<AutoEditStep>
    var zoomStrength: PhraseZoom.Strength = .subtle
    /// The edit shows how it was before the run (Before | After), while the run is the last step.
    var showsBefore = false
    /// How many undo steps there were once the run was one: Before and After work only while it is still the last.
    var stepsAfterRun: Int?
    /// The run's record while Before shows the edit without it (undone, so the edit has none).
    var beforeRecord: AutoEditRecord?
    /// The caption lines with the run, for its result while Before shows the edit without them.
    var beforeLines = 0
    /// The run going on.
    @ObservationIgnored var task: Task<Void, Never>?

    init(steps: Set<AutoEditStep>, phase: Phase = .choosing) {
        self.steps = steps
        self.phase = phase
    }

    func isOn(_ step: AutoEditStep) -> Bool {
        steps.contains(step)
    }

    func set(_ step: AutoEditStep, on: Bool) {
        if on { steps.insert(step) } else { steps.remove(step) }
    }

    var isWorking: Bool {
        if case .working = phase { true } else { false }
    }
}
