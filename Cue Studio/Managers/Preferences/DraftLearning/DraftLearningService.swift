//
//  DraftLearningService.swift
//  Cue Studio
//

import Foundation

/// Cue learns from what the creator does with its drafts. Each script Cue drafts keeps its words as they arrived (`CueDraft`, on this
/// iPhone); when the script is recorded and the creator had made it their own (`DraftEdits`), the opening of the version they recorded
/// becomes one of the examples of how they write, in the same place as "Sounds like me" (the last three; the oldest goes). A toast says
/// so: "Cue learned from this · Undo". Each draft teaches once; "Delete my Cue data" forgets the drafts and the examples.
@MainActor
@Observable
final class DraftLearningService {
    /// How many drafts are kept waiting for a take (the oldest goes).
    static let keptDrafts = 30

    private(set) var drafts: [UUID: CueDraft]

    private let profile: CreatorProfileService
    private let toast: ToastService
    private let defaults: UserDefaults

    init(profile: CreatorProfileService, toast: ToastService, defaults: UserDefaults = .standard) {
        self.profile = profile
        self.toast = toast
        self.defaults = defaults
        if let data = defaults.data(forKey: DefaultsKey.cueDrafts), let saved = try? JSONDecoder().decode([UUID: CueDraft].self, from: data) {
            drafts = saved
        } else {
            drafts = [:]
        }
    }

    /// Cue drafted this script: its words as they arrived. A second draft of the same script (Try again) takes the first one's place.
    func noteDraft(_ text: String, for scriptID: UUID) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        drafts[scriptID] = CueDraft(text: text)
        if drafts.count > Self.keptDrafts, let oldest = drafts.min(by: { $0.value.draftedAt < $1.value.draftedAt })?.key {
            drafts[oldest] = nil
        }
        persist()
    }

    /// The script's words started as a Cue draft that hasn't taught anything yet.
    func isCueDraft(_ scriptID: UUID) -> Bool {
        drafts[scriptID] != nil
    }

    /// A take of `script` was recorded: when the creator made Cue's draft their own, its opening becomes an example of how they write.
    /// A draft recorded as Cue wrote it waits (they may change it and record again).
    func tookTake(of script: Script?) {
        guard let script, let draft = drafts[script.id], DraftEdits.isTheirs(draft: draft.text, final: script.text) else { return }
        drafts[script.id] = nil
        persist()
        guard let example = profile.learnFromRecordedScript(script.text) else { return }
        toast.show(String(localized: "Cue learned from this"), action: ToastAction(title: String(localized: "Undo")) { [profile] in
            profile.removeApprovedSample(example.id)
        })
    }

    /// "Delete my Cue data".
    func clear() {
        drafts = [:]
        defaults.removeObject(forKey: DefaultsKey.cueDrafts)
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(drafts), forKey: DefaultsKey.cueDrafts)
    }
}
