//
//  SafeZoneChoice.swift
//  Cue Studio
//

import Foundation

/// Which safe zone the Selfie camera shows: a platform's, or the creator's own margins.
nonisolated enum SafeZoneChoice: Hashable, Sendable {
    case platform(Platform)
    case custom

    /// Platforms in the order the chips offer them. For a frame, the first one that fits is the
    /// default when the script's platform has none for it: Reels for 9:16, LinkedIn for 4:5.
    static let order: [Platform] = [.reels, .tiktok, .shorts, .stories, .linkedin, .youtube]

    /// The chips for a frame: the platforms whose zone was measured on it, then Custom. Horizontal
    /// video needs none.
    static func options(for aspect: AspectRatio, rules: PlatformRules) -> [SafeZoneChoice] {
        guard aspect != .landscape else { return [] }
        return order.filter { rules.safeZone(for: $0)?.aspect == aspect }.map { .platform($0) } + [.custom]
    }

    /// What the camera shows: the creator's pick while it fits the frame, else the script's
    /// platform, else the first platform measured on the frame, else Custom (1:1). Nil for
    /// horizontal video.
    static func resolve(pick: SafeZoneChoice?, scriptPlatform: Platform?, aspect: AspectRatio, rules: PlatformRules) -> SafeZoneChoice? {
        let options = options(for: aspect, rules: rules)
        if let pick, options.contains(pick) { return pick }
        if let scriptPlatform, options.contains(.platform(scriptPlatform)) { return .platform(scriptPlatform) }
        return options.first
    }

    /// Chip title: "Reels", "Custom".
    var label: String {
        switch self {
        case .platform(let platform): platform.label
        case .custom: String(localized: "Custom")
        }
    }

    /// Caption on the frame: "INSTAGRAM REELS SAFE AREA".
    var overlayLabel: String {
        switch self {
        case .platform(let platform): String(localized: "\(platform.destinationName.uppercased()) SAFE AREA")
        case .custom: String(localized: "CUSTOM SAFE AREA")
        }
    }

    /// Under "Show safe zone": "Instagram Reels · buttons, caption & header".
    var detail: String {
        switch self {
        case .platform(let platform): String(localized: "\(platform.destinationName) · buttons, caption & header")
        case .custom: String(localized: "Your own margins")
        }
    }

    /// For identifiers: "reels", "custom".
    var key: String {
        switch self {
        case .platform(let platform): platform.rawValue
        case .custom: "custom"
        }
    }
}
