//
//  AppLinks.swift
//  Cue Studio
//

import Foundation

/// External links shown in the app.
enum AppLinks {
    /// Cue uses Apple's standard license agreement.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Cue's privacy policy on Appolium Labs' site (its source: `AppoliumLabs/site/src/cue/privacy.html`), required for
    /// subscriptions on the App Store: Settings › About, Settings › Privacy & AI data and the paywall's small print open it.
    static let privacyPolicy = URL(string: "https://appoliumlabs.web.app/cue/privacy")
    /// Newer copies of `PlatformRules.json` (a static file, e.g. on GitHub Pages). While nil, the
    /// app uses the rules it shipped with.
    static let platformRules: URL? = nil
    /// How Anthropic treats what Ultra AI sends (no training on API data, deleted within 30 days, or kept up to 2 years when its safety systems
    /// flag a request as breaking its usage policy): Settings › Privacy & AI data › What Ultra AI sends.
    static let anthropicCommercialTerms = URL(string: "https://www.anthropic.com/legal/commercial-terms")
}
