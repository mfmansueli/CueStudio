//
//  IntentRouter.swift
//  Cue Studio
//

import Foundation

/// Hands App Intents' requests to the UI. Intents run outside the SwiftUI tree and can arrive before
/// the first screen exists (cold launch), so the request waits here until `RootView` takes it.
/// A singleton by necessity (ARCHITECTURE.md 2.2).
@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()

    private(set) var pending: IntentRoute?

    func request(_ route: IntentRoute) {
        pending = route
    }

    /// Returns the waiting request and clears it, so it runs once.
    func take() -> IntentRoute? {
        defer { pending = nil }
        return pending
    }
}
