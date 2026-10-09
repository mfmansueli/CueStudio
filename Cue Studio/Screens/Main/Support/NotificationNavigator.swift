//
//  NotificationNavigator.swift
//  Cue Studio
//

import Foundation

/// Takes a notification's destination to the screen it names, checking again that what it names is still there (a script deleted, a
/// network already posted, a tool no longer available): then the nearest useful place opens, with a line that says why. It only opens
/// screens: nothing records, edits, exports, writes, translates or posts until the creator does it there.
@MainActor
struct NotificationNavigator {
    let services: AppServices

    private var presentation: PresentationService { services.presentation }

    func go(to destination: NotificationDestination) async {
        if presentation.sheet != nil {
            // The sheet (a tool's introduction) leaves first: a cover or another sheet can't come up while it is still going.
            presentation.sheet = nil
            try? await Task.sleep(for: .milliseconds(450))
        }
        switch destination {
        case .script(let id), .voiceFollowing(let id):
            guard services.library.script(id: id) != nil else { return gone(String(localized: "That script is no longer in Cue")) }
            presentation.openScript(id)
        case .scriptEditor(let id):
            guard services.library.script(id: id) != nil else { return gone(String(localized: "That script is no longer in Cue")) }
            presentation.openScript(id, editing: true)
        case .takeReview(let id):
            guard let take = services.takes.take(id: id) else { return goneTake() }
            presentation.openReview(of: take)
        case .takeEditor(let id, let tool):
            guard let take = services.takes.take(id: id) else { return goneTake() }
            presentation.openReview(of: take, then: tool.map { .editTool($0) } ?? .edit)
        case .shareQueue(let takeID, let network):
            openQueue(takeID: takeID, network: network)
        case .logbook(let entryID):
            presentation.selectedTab = .scripts
            presentation.logbookFocus = entryID.flatMap { id in services.logbook.waiting.contains { $0.id == id } ? id : nil }
            presentation.present(.logbook)
        case .suggestedIdea(let key):
            openIdea(key: key)
        case .ideas, .voiceSetup, .importWriting:
            openWriting(destination)
        case .remote:
            openSettings([.remote])
        case .safeZone:
            openSettings([.prompter, .safeZone])
        case .universe, .yearInReview:
            presentation.selectedTab = .profile
            presentation.profilePath = [destination == .universe ? .universe : .yearInReview]
        case .newScript:
            presentation.selectedTab = .scripts
            presentation.present(.newScript)
        case .scripts:
            presentation.selectedTab = .scripts
            presentation.scriptsPath = []
        case .nextAction:
            let next = await services.notifications.nextActionDestination()
            if next != .nextAction { await go(to: next) }
        case .notificationSettings:
            openSettings([.notifications])
        }
    }

    /// Whether the object a destination names is still there.
    func exists(_ destination: NotificationDestination) -> Bool {
        switch destination {
        case .script(let id), .scriptEditor(let id), .voiceFollowing(let id): services.library.script(id: id) != nil
        case .takeReview(let id), .takeEditor(let id, _): services.takes.take(id: id) != nil
        case .shareQueue(let takeID, let network):
            services.shareQueue.queue(forTake: takeID).map { queue in network.map { waiting(queue).contains($0) } ?? !waiting(queue).isEmpty } ?? false
        case .logbook(let entryID): entryID.map { id in services.logbook.waiting.contains { $0.id == id } } ?? true
        case .suggestedIdea(let key): services.ideaSuggestions.idea(forKey: key) != nil
        case .ideas, .voiceSetup, .importWriting: services.aiStatus.isAvailable
        default: true
        }
    }

    // MARK: - Places

    /// The queue's next network, or the one named; a video already posted everywhere opens its review and says so.
    private func openQueue(takeID: UUID, network: ShareDestination?) {
        guard let take = services.takes.take(id: takeID) else { return goneTake() }
        guard let queue = services.shareQueue.queue(forTake: takeID), !waiting(queue).isEmpty else {
            presentation.openReview(of: take)
            services.toast.show(String(localized: "Already shared on the networks you chose"))
            return
        }
        if let network, waiting(queue).contains(network), queue.current?.network != network {
            presentation.openReview(of: take, then: .postLater(network))
        } else {
            presentation.openReview(of: take, then: .continueQueue)
        }
    }

    /// The idea goes into the card's field, ready to send; nothing is written until the creator sends it.
    private func openIdea(key: String) {
        presentation.selectedTab = .scripts
        presentation.scriptsPath = []
        guard let idea = services.ideaSuggestions.idea(forKey: key) else {
            services.toast.show(String(localized: "That idea isn’t here any more · try ↻ for another"))
            return
        }
        services.ideaDraft.text = idea.prompt
        services.ideaDraft.length = idea.length
    }

    /// Ideas, My Cue Voice and Import my writing need Apple Intelligence; without it, Scripts opens and says why.
    private func openWriting(_ destination: NotificationDestination) {
        presentation.selectedTab = .scripts
        guard services.aiStatus.isAvailable else {
            presentation.scriptsPath = []
            services.toast.show(String(localized: "Apple Intelligence isn’t available on this iPhone right now"))
            return
        }
        switch destination {
        case .ideas: presentation.present(.ideas)
        case .voiceSetup: presentation.present(.voiceSetup)
        default: presentation.present(.importWriting)
        }
    }

    private func openSettings(_ path: [SettingsRoute]) {
        presentation.selectedTab = .settings
        presentation.settingsPath = path
    }

    private func waiting(_ queue: ShareQueue) -> [ShareDestination] {
        queue.items.filter { $0.state != .posted }.map(\.network)
    }

    private func gone(_ message: String) {
        presentation.selectedTab = .scripts
        presentation.scriptsPath = []
        services.toast.show(message)
    }

    private func goneTake() {
        presentation.selectedTab = .takes
        services.toast.show(String(localized: "That recording is no longer in Cue"))
    }
}
