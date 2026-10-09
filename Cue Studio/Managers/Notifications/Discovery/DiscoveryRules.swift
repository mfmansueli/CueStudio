//
//  DiscoveryRules.swift
//  Cue Studio
//

import Foundation

/// Which tools fit the creator now, and on what (`NOTIFICATIONS.md` §4): every requirement met, a real object to try it on, not used yet,
/// not declined, not snoozed, and allowed on that channel. Pure. Tools shown the fewest times come first, then the catalog's order, so the
/// same one isn't offered again and again while another never is. The caps across tools are the planner's.
nonisolated enum DiscoveryRules {
    struct Offer: Hashable, Sendable {
        var intro: FeatureIntro
        var destination: NotificationDestination
        var projectKey: String
    }

    struct Declined: Hashable, Sendable {
        var feature: FeatureID
        var reason: SuppressionReason
    }

    /// Platforms whose own buttons cover the edges of a vertical video.
    static let socialPlatforms: Set<Platform> = [.tiktok, .reels, .shorts, .stories]
    /// A take shorter than this has nothing for an editing tool to show.
    static let minimumTakeLength: TimeInterval = 3
    /// Clean Up needs a take long enough to have pauses.
    static let cleanUpTakeLength: TimeInterval = 10

    static func offers(
        facts: NotificationFacts, state: NotificationState, channel: FeatureIntro.Channel, catalog: [FeatureIntro] = FeatureCatalog.all
    ) -> (offers: [Offer], declined: [Declined]) {
        var offers: [(Offer, Int, Int)] = []
        var declined: [Declined] = []
        for (index, intro) in catalog.enumerated() where intro.channels.contains(channel) {
            if let reason = blocker(for: intro.feature, facts: facts, state: state) {
                declined.append(Declined(feature: intro.feature, reason: reason))
                continue
            }
            guard intro.requirements.allSatisfy({ meets($0, facts) }), let target = resolve(intro, facts: facts) else {
                declined.append(Declined(feature: intro.feature, reason: .unavailable))
                continue
            }
            let shown = state.exposures.filter { $0.feature == intro.feature }.count
            offers.append((Offer(intro: intro, destination: target.destination, projectKey: target.projectKey), shown, index))
        }
        let ordered = offers.sorted { ($0.1, $0.2) < ($1.1, $1.2) }.map(\.0)
        return (ordered, declined)
    }

    /// Used, declined or snoozed: why the tool is out, before looking at anything else.
    static func blocker(for feature: FeatureID, facts: NotificationFacts, state: NotificationState) -> SuppressionReason? {
        if facts.adopted.contains(feature) || state.adopted[feature.rawValue] != nil { return .adopted }
        if state.isNotInterested(in: feature) { return .notInterested }
        if let until = state.snoozedFeatures[feature.rawValue], until > facts.now { return .snoozed }
        return nil
    }

    // MARK: - Requirements

    static func meets(_ requirement: FeatureRequirement, _ facts: NotificationFacts) -> Bool {
        switch requirement {
        case .appleIntelligence: facts.capabilities.aiWriting
        case .scripts(let count): facts.scripts.count >= count
        case .recorded: facts.hasRecorded
        case .finishedVideo: facts.takes.contains(where: \.isExported)
        case .voiceNotConfigured: !facts.profile.voiceConfigured
        case .voiceConfigured: facts.profile.voiceConfigured
        case .notImported: !facts.profile.hasImportedWriting
        case .topics: facts.profile.hasTopics
        case .steadyPrompter: facts.prompterIsSteady
        case .backgrounds: facts.capabilities.backgrounds
        case .sharedVideos(let count): facts.sharedVideos >= count
        }
    }

    // MARK: - Targets

    private static func resolve(_ intro: FeatureIntro, facts: NotificationFacts) -> (destination: NotificationDestination, projectKey: String)? {
        let placeKey = "feature.\(intro.feature.rawValue)"
        switch intro.target {
        case .place(let destination):
            return (destination, placeKey)
        case .readyScript:
            let ready = facts.scripts.filter { script in
                script.state == .ready && facts.takes(of: script.id).isEmpty
                    && script.language.map { facts.capabilities.voiceFollowing.contains($0) } == true
            }
            guard let script = ready.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
            return (.voiceFollowing(scriptID: script.id), ProjectKey.script(script.id))
        case .take(let need, let tool):
            guard let take = suitableTake(need, facts: facts) else { return nil }
            return (.takeEditor(take.id, tool: tool), take.scriptID.map(ProjectKey.script) ?? ProjectKey.take(take.id))
        case .socialVideo(let destination):
            let social = facts.takes.contains { $0.platform.map(socialPlatforms.contains) == true }
                || facts.scripts.contains { socialPlatforms.contains($0.platform) }
            return social ? (destination, placeKey) : nil
        }
    }

    /// The take to try a tool on: one still being made first, then the newest.
    static func suitableTake(_ need: DiscoveryTarget.TakeNeed, facts: NotificationFacts) -> NotificationFacts.TakeFact? {
        let fitting = facts.takes.filter { take in
            guard take.duration >= minimumTakeLength else { return false }
            switch need {
            case .any: return true
            case .cleanUp:
                return take.duration >= cleanUpTakeLength && !take.cleanUpAnalyzed
                    && take.language.map { facts.capabilities.captions.contains($0) } == true
            case .withoutCaptions:
                return !take.hasCaptions && take.language.map { facts.capabilities.captions.contains($0) } == true
            case .translatableCaptions:
                return take.hasCaptions && take.language.map { facts.capabilities.captionTranslation.contains($0) } == true
            case .unfinished:
                return !take.videoExported
            }
        }
        return fitting.max { lhs, rhs in
            (!lhs.videoExported ? 1 : 0, lhs.recordedAt) < (!rhs.videoExported ? 1 : 0, rhs.recordedAt)
        }
    }
}
