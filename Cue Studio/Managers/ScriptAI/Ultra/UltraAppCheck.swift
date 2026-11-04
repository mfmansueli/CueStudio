//
//  UltraAppCheck.swift
//  Cue Studio
//

import FirebaseAppCheck
import FirebaseCore
import Foundation

/// Firebase App Check for Cue's server (`CueServerUltraClient`): the token that proves a request comes from Cue on a real iPhone. Installed with
/// Firebase at launch (`TelemetryManager.start`), but it asks Apple and Google for nothing until Ultra AI makes its first call: no token is
/// fetched or refreshed on its own (`FirebaseAppCheckTokenAutoRefreshEnabled` is off in Info.plist, and again here).
nonisolated enum UltraAppCheck {
    struct Unavailable: Error {}

    /// The provider for every Firebase app; before `FirebaseApp.configure()`.
    static func install() {
        AppCheck.setAppCheckProviderFactory(CueAppCheckProviderFactory())
    }

    /// After `FirebaseApp.configure()`: tokens only when a call asks.
    static func holdTokensUntilAsked() {
        guard let app = FirebaseApp.app() else { return }
        AppCheck.appCheck(app: app)?.isTokenAutoRefreshEnabled = false
    }

    /// Firebase runs in this launch (never in tests or previews, `TelemetryPolicy`).
    static var isReady: Bool { FirebaseApp.app() != nil }

    /// A token for the next call (cached by the SDK while it is valid, an hour).
    static func token() async throws -> String {
        guard let app = FirebaseApp.app(), let appCheck = AppCheck.appCheck(app: app) else { throw Unavailable() }
        return try await appCheck.token(forcingRefresh: false).token
    }
}
