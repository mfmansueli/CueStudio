//
//  ShareIntegrationConfiguration.swift
//  Cue Studio
//

import Foundation

/// The IDs the platform integrations need, read from Info.plist. Cue ships without them (they belong to the developer
/// accounts that register the app with TikTok and Meta): while one is empty, its integration is off and the destination
/// uses a fallback, never a pretend delivery. See `SHARING.md` for where each value comes from.
nonisolated struct ShareIntegrationConfiguration: Equatable, Sendable {
    /// TikTok for Developers › the app's Client key (`TikTokClientKey`).
    var tikTokClientKey: String?
    /// A universal link of Cue's, registered as the redirect URI of the TikTok app; Share Kit calls back through it
    /// (`TikTokShareRedirectURI`).
    var tikTokRedirectURI: String?
    /// The Meta app ID that Instagram's hand-off asks for (`MetaAppID`).
    var metaAppID: String?

    init(tikTokClientKey: String? = nil, tikTokRedirectURI: String? = nil, metaAppID: String? = nil) {
        self.tikTokClientKey = Self.clean(tikTokClientKey)
        self.tikTokRedirectURI = Self.clean(tikTokRedirectURI)
        self.metaAppID = Self.clean(metaAppID)
    }

    /// Share Kit needs both: the client key (the SDK reads it from Info.plist) and the redirect URI.
    var isTikTokConfigured: Bool { tikTokClientKey != nil && tikTokRedirectURI != nil }
    var isInstagramConfigured: Bool { metaAppID != nil }

    static func fromBundle(_ bundle: Bundle = .main) -> ShareIntegrationConfiguration {
        func value(_ key: String) -> String? { bundle.object(forInfoDictionaryKey: key) as? String }
        return ShareIntegrationConfiguration(
            tikTokClientKey: value("TikTokClientKey"), tikTokRedirectURI: value("TikTokShareRedirectURI"), metaAppID: value("MetaAppID")
        )
    }

    /// Empty, blank and unexpanded build settings (`$(NAME)`) all mean "not set".
    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }
}
