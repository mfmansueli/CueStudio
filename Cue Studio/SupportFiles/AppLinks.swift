//
//  AppLinks.swift
//  Cue Studio
//

import Foundation

/// External links shown in the app.
enum AppLinks {
    /// Cue uses Apple's standard license agreement.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Required for subscriptions on the App Store. Set before the first release; the link stays
    /// hidden while it is nil.
    static let privacyPolicy: URL? = nil
    /// Newer copies of `PlatformRules.json` (a static file, e.g. on GitHub Pages). While nil, the
    /// app uses the rules it shipped with.
    static let platformRules: URL? = nil
    /// How Google treats what Ultra AI sends (no training on it, the 24-hour cache, abuse logs): Settings › Privacy & AI data › What Ultra AI sends.
    static let googleCloudDataTerms = URL(string: "https://cloud.google.com/vertex-ai/generative-ai/docs/data-governance")
}
