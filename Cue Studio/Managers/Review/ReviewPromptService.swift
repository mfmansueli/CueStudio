//
//  ReviewPromptService.swift
//  Cue Studio
//

import Foundation

/// Keeps `ReviewPromptPolicy` and says when Cue may ask for a rating: a video left Cue (`ExportLedgerService.firstDelivered`) and the policy
/// agrees, so `isPending` turns on; the take's review asks with SwiftUI's `requestReview` once its celebration closes, a calm moment
/// (`TakeReviewView`), and `markAsked` keeps the version.
@MainActor
@Observable
final class ReviewPromptService {
    private(set) var isPending = false
    @ObservationIgnored private var policy: ReviewPromptPolicy
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let version: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let exportsLeft: @MainActor () -> Int?
    /// "Help improve Cue" on: the moment is measured (`TelemetryManager`).
    @ObservationIgnored var report: (@MainActor () -> Void)?

    init(
        defaults: UserDefaults, exportsLeft: @escaping @MainActor () -> Int?,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.exportsLeft = exportsLeft
        self.version = version
        self.now = now
        let saved = defaults.data(forKey: DefaultsKey.reviewPrompt).flatMap { try? JSONDecoder().decode(ReviewPromptPolicy.self, from: $0) }
        policy = saved ?? ReviewPromptPolicy()
        if policy.installDay == nil {
            policy.installDay = ReviewPromptPolicy.day(now())
            save()
        }
    }

    /// A video left Cue for the first time.
    func delivered() {
        policy.deliveries += 1
        save()
        if policy.asks(today: ReviewPromptPolicy.day(now()), version: version, exportsLeft: exportsLeft()) { isPending = true }
    }

    /// An export failed: no rating asked today.
    func failed() {
        policy.failureDay = ReviewPromptPolicy.day(now())
        isPending = false
        save()
    }

    /// The prompt was asked (iOS decides whether it shows).
    func markAsked() {
        guard isPending else { return }
        isPending = false
        policy.askedVersion = version
        save()
        report?()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(policy), forKey: DefaultsKey.reviewPrompt)
    }
}
