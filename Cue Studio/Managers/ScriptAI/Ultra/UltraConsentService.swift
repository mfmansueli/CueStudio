//
//  UltraConsentService.swift
//  Cue Studio
//

import Foundation

/// The creator's explicit permission for Ultra to send their request and voice preferences to Anthropic, apart from the Apple Intelligence switch:
/// allowing or revoking one never changes the other. Revoking stops any Ultra request from going out from then on, also one waiting between its
/// calls (`UltraScriptService` asks again before each). "Delete my Cue data" revokes it too (`DataEraserService`): the next Ultra script asks again.
@MainActor
@Observable
final class UltraConsentService {
    /// When the creator allowed it, for the disclosure version in the key: a new disclosure (what is sent changes) asks again.
    static let key = "ultra.consent.v1"

    private(set) var grantedAt: Date?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        grantedAt = defaults.object(forKey: Self.key) as? Date
    }

    var isGranted: Bool { grantedAt != nil }

    /// "Allow" on the disclosure (`UltraConsentSheet`).
    func grant() {
        let date = now()
        grantedAt = date
        defaults.set(date, forKey: Self.key)
    }

    /// Turned off in Settings (or "Delete my Cue data"): nothing more is sent.
    func revoke() {
        grantedAt = nil
        defaults.removeObject(forKey: Self.key)
    }
}
