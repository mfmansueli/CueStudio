//
//  AppNotificationFacts.swift
//  Cue Studio
//

import Foundation

/// The facts read from the app's own services when Cue plans or opens a notification: nothing is analysed, transcribed or asked of the
/// model for it (language support is asked of the system once and kept by `LanguageCapabilityService`; a language is read from a script's
/// text only for the scripts and takes that could be offered a tool). Records made for the UI tests' samples are only here because the
/// tests launch with them; a real install has none.
final class AppNotificationFacts: NotificationFactsSource {
    struct Sources {
        let library: ScriptLibraryService
        let takes: TakeLibraryService
        let drafts: QuickEditDraftStoring
        let shareQueue: ShareQueueService
        let logbook: LogbookService
        let ideas: IdeaSuggestionService
        let profile: CreatorProfileService
        let preferences: PreferencesService
        let capabilities: LanguageCapabilityService
        let languages: LanguageService
        let milestones: MilestoneService
        /// Apple Intelligence is on in Cue and can write here.
        let aiWriting: () -> Bool
        /// The year whose review is ready (December onwards, enough videos), from the universe's own rules.
        let yearReview: () -> Int?
        /// Person segmentation works on this iPhone (asked once).
        let backgrounds: () async -> Bool
    }

    /// Languages asked about at most, newest first: enough for the projects that could be offered a tool.
    private static let languageLimit = 4

    private let sources: Sources

    init(sources: Sources) {
        self.sources = sources
    }

    func facts(now: Date, events: Set<FeatureID>, capabilities: Bool) async -> NotificationFacts {
        let library = sources.library.scripts
        let takes = sources.takes.takes
        var facts = NotificationFacts(now: now)
        let takeCounts = Dictionary(grouping: takes.compactMap(\.scriptID)) { $0 }.mapValues(\.count)
        facts.scripts = library.map { script in
            NotificationFacts.ScriptFact(
                id: script.id, title: script.displayTitle, state: script.state(takeCount: takeCounts[script.id] ?? 0),
                wordCount: ReadTime.wordCount(in: CueParser.stripCues(script.text)), createdAt: script.createdAt,
                updatedAt: script.updatedAt, language: nil, platform: script.platform
            )
        }
        facts.takes = takeFacts(takes, scripts: library)
        if capabilities { fillLanguages(&facts, scripts: library) }
        facts.queues = sources.shareQueue.queues.map { queue in
            NotificationFacts.QueueFact(
                takeID: queue.takeID, title: queue.title,
                waiting: queue.items.filter { $0.state == .pending }.map(\.network) + queue.later.map(\.network), updatedAt: queue.updatedAt
            )
        }
        facts.notes = sources.logbook.waiting.map { NotificationFacts.NoteFact(id: $0.id, createdAt: $0.createdAt) }
        facts.ideas = sources.ideas.unseenModelIdeas.map { idea in
            NotificationFacts.IdeaFact(key: IdeaKey.of(idea), topicLabel: idea.topic == nil ? idea.niche.label : nil)
        }
        let profile = sources.profile.profile
        facts.profile = NotificationFacts.Profile(
            hasTopics: profile.topicCount > 0, voiceConfigured: profile.hasMinimumVoice,
            hasImportedWriting: !profile.excerpts.isEmpty || profile.fingerprint != nil
        )
        let prompter = sources.preferences.prompter
        facts.prompterIsSteady = prompter.scrollMode == .steady
        facts.adopted = FeatureAdoption.adopted(
            takeTools: facts.takes.map(\.toolsUsed), profile: facts.profile, hasLogbookEntries: !sources.logbook.entries.isEmpty,
            prompterFollowsVoice: prompter.scrollMode == .voice, showsSafeZone: prompter.safeZoneKey != nil, events: events
        )
        facts.sharedVideos = Set(sources.milestones.records.map(\.takeID)).count
        facts.yearReviewReady = sources.yearReview()
        facts.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        if capabilities { facts.capabilities = await self.capabilities(for: facts) }
        return facts
    }

    // MARK: - Takes

    private func takeFacts(_ takes: [Take], scripts: [Script]) -> [NotificationFacts.TakeFact] {
        let byVideo = Dictionary(grouping: takes) { $0.scriptID ?? $0.id }
        let drafts = sources.drafts
        return takes.map { take in
            let video = byVideo[take.scriptID ?? take.id] ?? [take]
            let stage = TakeStage(takes: video, hasDraft: { drafts.hasDraft(for: $0) })
            // An edit still open is what the creator sees; the file is read only when there is one.
            let edit = drafts.hasDraft(for: take.id) ? drafts.draft(for: take.id)?.edit ?? take.edit : take.edit
            return NotificationFacts.TakeFact(
                id: take.id, scriptID: take.scriptID, title: take.scriptTitle, recordedAt: take.recordedAt, duration: take.duration,
                stage: stage, isExported: take.isExported, videoExported: video.contains(where: \.isExported), platform: take.platform,
                language: nil, hasCaptions: !(edit?.captions.isEmpty ?? true), cleanUpAnalyzed: edit?.cleanUpAnalyzed ?? false,
                toolsUsed: FeatureAdoption.tools(in: edit)
            )
        }
    }

    // MARK: - Languages and what this iPhone does in them

    /// Reads the language only where a tool could be offered: ready scripts with no take, and takes.
    private func fillLanguages(_ facts: inout NotificationFacts, scripts: [Script]) {
        let byID = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })
        let fallback = sources.languages.scriptLanguage ?? sources.languages.interfaceLanguage
        func language(of script: Script?) -> CueLanguage {
            guard let script else { return fallback }
            return script.language ?? LanguageDetector.language(in: script.text) ?? fallback
        }
        for index in facts.scripts.indices where facts.scripts[index].state == .ready {
            facts.scripts[index].language = language(of: byID[facts.scripts[index].id])
        }
        let takes = sources.takes.takes
        for index in facts.takes.indices {
            let take = takes.first { $0.id == facts.takes[index].id }
            facts.takes[index].language = take?.edit?.captionLanguage ?? language(of: take?.scriptReference ?? take?.scriptID.flatMap { byID[$0] })
        }
    }

    private func capabilities(for facts: NotificationFacts) async -> NotificationFacts.Capabilities {
        var capabilities = NotificationFacts.Capabilities()
        capabilities.aiWriting = sources.aiWriting()
        let wanted = facts.takes.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.language)
            + facts.scripts.sorted { $0.updatedAt > $1.updatedAt }.compactMap(\.language)
        var languages: [CueLanguage] = []
        for language in wanted where !languages.contains(language) && languages.count < Self.languageLimit { languages.append(language) }
        let service = sources.capabilities
        let interface = sources.languages.interfaceLanguage
        for language in languages {
            if await service.support(.voiceFollowing, for: language).isUsable { capabilities.voiceFollowing.insert(language) }
            if await service.support(.captions, for: language).isUsable { capabilities.captions.insert(language) }
            let target: CueLanguage = language == interface ? (language == .english ? .spanish : .english) : interface
            let source = Locale.Language(identifier: language.rawValue)
            if await service.translation(from: source, to: target).isUsable { capabilities.captionTranslation.insert(language) }
        }
        capabilities.backgrounds = facts.hasRecorded ? await sources.backgrounds() : false
        return capabilities
    }
}
