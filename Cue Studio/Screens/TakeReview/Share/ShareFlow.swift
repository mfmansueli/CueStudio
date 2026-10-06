//
//  ShareFlow.swift
//  Cue Studio
//

import Foundation
import UIKit

/// "Share to universe" (8.1), from the networks to the last "Posted on {network}?": pick the networks, export once (and save to Photos when asked),
/// then take them one at a time through the system share sheet. Cue only knows what the creator tells it: **Yes, it's live** is what makes a network
/// posted, and what lights its planet. Phase A: the system share sheet for every network (`ShareIntegrationConfiguration.integrationsEnabled`).
@MainActor
@Observable
final class ShareFlow {
    /// How many times the explanation of the queue is shown (with two or more networks).
    static let explainerTimes = 2

    var step: ShareFlowStep?
    /// The networks picked, in the order they will be posted.
    private(set) var picked: [ShareDestination] = []
    var alsoSavesToPhotos = true
    private(set) var isStarting = false
    /// The caption on the pasteboard for this step; the creator can edit it.
    var caption = ""
    /// The milestone the first confirmed network reached, for the story after the send-off.
    private(set) var reachedMilestone: Int?
    /// The networks the creator said were live, in this run of the queue (the queue itself goes once all are posted).
    private(set) var live: [ShareDestination] = []

    /// The file the networks share.
    private(set) var video: ExportedVideo?
    /// All the networks are done: the send-off plays.
    @ObservationIgnored var onFinished: (ExportedVideo, [ShareDestination]) -> Void = { _, _ in }
    /// "Edit first": the review opens the editor.
    @ObservationIgnored var onEditFirst: () -> Void = {}
    /// The pasteboard (a test swaps it).
    @ObservationIgnored var copies: (String) -> Void = { UIPasteboard.general.string = $0 }
    /// How long a sheet takes to leave before another presentation can come up (a test sets it to zero).
    @ObservationIgnored var settle: Duration = .milliseconds(500)

    private let review: TakeReviewViewModel
    private let queues: ShareQueueService
    private let milestones: MilestoneService
    private let library: ScriptLibraryService
    private let defaults: UserDefaults
    private let toast: ToastService

    init(
        review: TakeReviewViewModel, queues: ShareQueueService, milestones: MilestoneService, library: ScriptLibraryService,
        defaults: UserDefaults, toast: ToastService
    ) {
        self.review = review
        self.queues = queues
        self.milestones = milestones
        self.library = library
        self.defaults = defaults
        self.toast = toast
        review.queueInterceptor = { [weak self] destination, result in self?.sheetEnded(for: destination, result: result) ?? false }
        review.queueOperation = { [weak self] in self?.queue?.operationID }
    }

    // MARK: - Reading

    var queue: ShareQueue? { queues.queue(forTake: review.takeID) }

    /// The queue's current network and where it stands, for the step.
    var current: ShareQueueItem? { queue?.current }

    var canStart: Bool { !picked.isEmpty && !isStarting }

    func isPicked(_ network: ShareDestination) -> Bool { picked.contains(network) }

    /// "Share to 3 networks", "Share to TikTok", or "Pick a network".
    var startTitle: String {
        switch picked.count {
        case 0: String(localized: "Pick a network")
        case 1: String(localized: "Share to \(picked[0].platform.label)")
        default: String(localized: "Share to \(picked.count) networks")
        }
    }

    /// Under the button: what it costs. Nil when it costs nothing to say.
    var costLine: (text: String, isWarning: Bool)? {
        guard let video else { return nil }
        guard let left = review.exportsLeft else { return (String(localized: "Pro · unlimited exports"), false) }
        if review.isCounted(video) { return (String(localized: "This video's export is already counted"), false) }
        if left == 0 { return (String(localized: "No free exports left · see Pro"), true) }
        return (String(localized: "Uses 1 free export · \(left - 1) left after this"), false)
    }

    // MARK: - The networks

    /// The networks sheet over "Ready to travel": the one the script is for is already ticked.
    func openPicker(with video: ExportedVideo) {
        self.video = video
        if picked.isEmpty, let platform = video.take.platform {
            let network = ShareDestination(platform)
            if ShareNetworkLine.networks.contains(network) { picked = [network] }
        }
        step = .picker
    }

    func toggle(_ network: ShareDestination) {
        if let index = picked.firstIndex(of: network) { picked.remove(at: index) } else { picked.append(network) }
    }

    /// "Share to 3 networks": one export for all of them, then the first one's step (after the explanation, the first times).
    func start() async {
        guard canStart else { return }
        isStarting = true
        defer { isStarting = false }
        guard let prepared = await review.prepare(alsoSavingToPhotos: alsoSavesToPhotos, continuing: queue?.operationID) else {
            // The free exports are gone ("Your video is ready" is up) or it failed (a toast told): the networks stay picked.
            return
        }
        video = prepared
        guard let take = review.take else { return }
        queues.begin(takeID: take.id, operationID: prepared.operationID, title: take.scriptTitle, networks: picked)
        live = []
        if picked.count >= 2, defaults.integer(forKey: DefaultsKey.queueExplainerShown) < Self.explainerTimes {
            step = .explainer
        } else {
            openCurrent()
        }
    }

    func finishExplainer() {
        defaults.set(defaults.integer(forKey: DefaultsKey.queueExplainerShown) + 1, forKey: DefaultsKey.queueExplainerShown)
        openCurrent()
    }

    // MARK: - A network's turn

    private func openCurrent() {
        guard let current else { return finish() }
        caption = review.postCaption
        copy()
        step = .step(current.network)
    }

    /// "Caption copied" and "Copy again".
    func copy() { copies(caption) }

    /// "Send to TikTok": the system share sheet with the file; the sheet closes first, and comes back when the share sheet ends.
    func send(to network: ShareDestination) async {
        guard let video else { return }
        copy()
        step = nil
        try? await Task.sleep(for: settle)
        await review.send(video, to: network)
    }

    /// The share sheet of a queue's network ended: a finished one asks "Posted on {network}?", a cancelled one goes back to the step.
    private func sheetEnded(for network: ShareDestination, result: ActivityResult) -> Bool {
        guard let queue, queue.current?.network == network else { return false }
        Task { @MainActor in
            try? await Task.sleep(for: settle)
            if case .completed = result { step = .confirm(network) } else { step = .step(network) }
        }
        return true
    }

    /// "Yes, it's live": the network is posted, its planet lights, and the next one comes up.
    func confirmLive(_ network: ShareDestination) {
        guard let take = review.take else { return }
        let topic = library.script(id: take.scriptID)?.topic
        if let reached = milestones.recordShare(of: take.id, platform: network.platform, topic: topic) { reachedMilestone = reached }
        if !live.contains(network) { live.append(network) }
        queues.markPosted(takeID: take.id, network: network)
        advance()
    }

    /// "Not yet": back to its step, where it can be sent again or left for later.
    func notYet(_ network: ShareDestination) { step = .step(network) }

    /// "Post later": this network waits, the next one comes up.
    func postLater(_ network: ShareDestination) {
        queues.postLater(takeID: review.takeID, network: network)
        advance()
    }

    /// ✕: whatever is left goes to later, and the card brings it back.
    func close() {
        guard queue != nil else { step = nil; return }
        queues.moveRestToLater(takeID: review.takeID)
        step = nil
        toast.show(String(localized: "Saved · continue anytime"))
    }

    func editFirst() {
        step = nil
        onEditFirst()
    }

    private func advance() {
        if current != nil { openCurrent() } else { finish() }
    }

    /// Nothing is waiting: the send-off for the networks that went live (or just a toast when none did).
    private func finish() {
        step = nil
        guard let video else { return }
        guard !live.isEmpty else {
            toast.show(String(localized: "Saved · continue anytime"))
            return
        }
        onFinished(video, live)
    }

    // MARK: - Later and the card

    /// "POST TO LINKEDIN LATER" and "Continue": the network that waits comes up as the current one. The file is made again when the system cleared it.
    func resume(_ network: ShareDestination? = nil) async {
        guard let queue else { return }
        let target = network ?? queue.current?.network ?? queue.later.first?.network
        guard let target else { return }
        live = queue.posted
        if queue.current?.network != target { queues.resume(takeID: queue.takeID, network: target) }
        await review.render(continuing: queue.operationID)
        guard case .readyToTravel(let rendered)? = review.celebration else { return }
        video = rendered
        step = .step(target)
        caption = review.postCaption
        copy()
    }
}
