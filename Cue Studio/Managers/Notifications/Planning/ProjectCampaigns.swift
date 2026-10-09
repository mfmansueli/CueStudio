//
//  ProjectCampaigns.swift
//  Cue Studio
//

import Foundation

/// The project nudges (`NOTIFICATIONS.md` §3), read from the real state of each project: **one next step per project**, the most
/// advanced one, never a nudge per stage. A script and its takes are one project; a freestyle take is its own. Every wait counts from the
/// project's own last change, and never from before `startedAt` (the first time this build ran the notifications), so an update never
/// sends every old draft at once.
nonisolated enum ProjectCampaigns {
    static func candidates(facts: NotificationFacts, startedAt: Date, policy: NotificationPolicy) -> [CampaignCandidate] {
        var found: [CampaignCandidate] = []
        let ready = facts.scripts.filter { $0.state == .ready }
        let firstReady: UUID? = facts.hasRecorded ? nil : ready.min { $0.createdAt < $1.createdAt }?.id
        for script in facts.scripts {
            if let candidate = nextStep(for: script, facts: facts, firstReady: firstReady, startedAt: startedAt, policy: policy) {
                found.append(candidate)
            }
        }
        // Freestyle takes are a project each; the takes of a script that was deleted stay one project.
        let loose = Dictionary(grouping: facts.takes.filter { facts.script($0.scriptID) == nil }) { $0.scriptID ?? $0.id }
        for (id, takes) in loose.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            let key = takes.first?.scriptID == nil ? ProjectKey.take(id) : ProjectKey.script(id)
            if let candidate = nextStep(forLoose: takes, facts: facts, key: key, startedAt: startedAt, policy: policy) { found.append(candidate) }
        }
        if let note = savedIdea(facts: facts, startedAt: startedAt, policy: policy) { found.append(note) }
        return found
    }

    // MARK: - One project

    private static func nextStep(
        for script: NotificationFacts.ScriptFact, facts: NotificationFacts, firstReady: UUID?, startedAt: Date, policy: NotificationPolicy
    ) -> CampaignCandidate? {
        let key = ProjectKey.script(script.id)
        let takes = facts.takes(of: script.id)
        if let sharing = sharing(takes: takes, facts: facts, key: key, startedAt: startedAt, policy: policy) { return sharing }
        if !takes.isEmpty { return finishing(takes: takes, title: script.title, key: key, startedAt: startedAt, policy: policy) }
        switch script.state {
        case .ready:
            let campaign: NotificationCampaign = script.id == firstReady ? .firstRecording : .readyToRecord
            return CampaignCandidate(
                campaign: campaign, feature: nil, projectKey: key,
                earliest: max(script.updatedAt, startedAt) + policy.readyToRecordDelay,
                destination: .script(script.id), subject: .project(campaign, title: script.title, network: nil)
            )
        case .draft:
            guard script.wordCount >= policy.meaningfulWords else { return nil }
            return CampaignCandidate(
                campaign: .unfinishedScript, feature: nil, projectKey: key,
                earliest: max(script.updatedAt, startedAt) + policy.unfinishedScriptDelay,
                destination: .scriptEditor(script.id), subject: .project(.unfinishedScript, title: script.title, network: nil)
            )
        case .recorded:
            return nil
        }
    }

    private static func nextStep(
        forLoose takes: [NotificationFacts.TakeFact], facts: NotificationFacts, key: String, startedAt: Date, policy: NotificationPolicy
    ) -> CampaignCandidate? {
        if let sharing = sharing(takes: takes, facts: facts, key: key, startedAt: startedAt, policy: policy) { return sharing }
        return finishing(takes: takes, title: takes.first?.title ?? "", key: key, startedAt: startedAt, policy: policy)
    }

    /// A queue with networks still waiting: the next one.
    private static func sharing(
        takes: [NotificationFacts.TakeFact], facts: NotificationFacts, key: String, startedAt: Date, policy: NotificationPolicy
    ) -> CampaignCandidate? {
        let ids = Set(takes.map(\.id))
        guard let queue = facts.queues.first(where: { ids.contains($0.takeID) && !$0.waiting.isEmpty }) else { return nil }
        let since = max(queue.updatedAt ?? startedAt, startedAt)
        let network = queue.waiting.first
        return CampaignCandidate(
            campaign: .incompleteSharing, feature: nil, projectKey: key, earliest: since + policy.sharingDelay,
            destination: .shareQueue(takeID: queue.takeID, network: nil),
            subject: .project(.incompleteSharing, title: queue.title, network: network)
        )
    }

    /// Takes with work left and nothing exported: the step their stage asks for.
    private static func finishing(
        takes: [NotificationFacts.TakeFact], title: String, key: String, startedAt: Date, policy: NotificationPolicy
    ) -> CampaignCandidate? {
        guard let latest = takes.max(by: { $0.recordedAt < $1.recordedAt }), !takes.contains(where: \.isExported),
              latest.stage != .shared else { return nil }
        let destination: NotificationDestination = latest.stage == .edit ? .takeEditor(latest.id, tool: nil) : .takeReview(latest.id)
        return CampaignCandidate(
            campaign: .recordingToFinish, feature: nil, projectKey: key,
            earliest: max(latest.recordedAt, startedAt) + policy.recordingToFinishDelay,
            destination: destination, subject: .project(.recordingToFinish, title: title, network: nil)
        )
    }

    /// The oldest note still waiting in the Logbook, a week after it was caught (one at a time: the Logbook is the creator's, not a queue).
    private static func savedIdea(facts: NotificationFacts, startedAt: Date, policy: NotificationPolicy) -> CampaignCandidate? {
        guard let note = facts.notes.min(by: { $0.createdAt < $1.createdAt }) else { return nil }
        return CampaignCandidate(
            campaign: .savedIdea, feature: nil, projectKey: "note.\(note.id.uuidString)",
            earliest: max(note.createdAt + policy.savedIdeaAge, startedAt + policy.sharingDelay),
            destination: .logbook(entryID: note.id), subject: .project(.savedIdea, title: "", network: nil)
        )
    }

    // MARK: - After a break

    /// Two attempts, 7 and 21 days after the last activity, each about the most useful real project (or the ways to start one). They take
    /// the place of every other automatic notification from the first attempt on (`NotificationPlanner`), and nothing follows the second
    /// until the creator comes back.
    static func returnAttempts(
        after lastActivity: Date, projects: [CampaignCandidate], policy: NotificationPolicy
    ) -> [CampaignCandidate] {
        let best = projects.filter { $0.campaign != .savedIdea }.min { ($0.campaign.priority, $0.earliest) < ($1.campaign.priority, $1.earliest) }
        return policy.returnAttempts.enumerated().map { index, delay in
            CampaignCandidate(
                campaign: .returnAfterInactivity, feature: nil, projectKey: "return.\(index + 1)", earliest: lastActivity + delay,
                destination: best?.destination ?? .newScript, subject: best?.subject ?? .entryPoint
            )
        }
    }
}
