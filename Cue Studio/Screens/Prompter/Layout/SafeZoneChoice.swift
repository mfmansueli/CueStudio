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

    /// What the camera shows: Custom while the creator picked it, else the recording's network when its zone was measured on the
    /// frame (YouTube's vertical video is a Short: Shorts' zone), else Custom where only it fits (1:1), else none: never another
    /// network's zone (a Reels video at 4:5 shows no LinkedIn zone). Without a network, the first measured on the frame. Nil for 16:9.
    static func resolve(pick: SafeZoneChoice?, network: Platform?, aspect: AspectRatio, rules: PlatformRules) -> SafeZoneChoice? {
        let options = options(for: aspect, rules: rules)
        if let pick, options.contains(pick) { return pick }
        guard let network else { return options.first }
        if options.contains(.platform(network)) { return .platform(network) }
        // A vertical video for YouTube is a Short: the zone of the same app. Another app's zone would name a network the video isn't for.
        if network == .youtube, options.contains(.platform(.shorts)) { return .platform(.shorts) }
        return options.first == .custom ? .custom : nil
    }

    /// The creator's saved pick: Custom, or nil to follow the recording's network. A network saved by an older Settings page (TikTok,
    /// Reels…) is no pick any more: the zone always follows the network the video is recorded for.
    static func pick(fromKey key: String?) -> SafeZoneChoice? {
        key == SafeZoneChoice.custom.key ? .custom : nil
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

    /// For identifiers: "reels", "custom".
    var key: String {
        switch self {
        case .platform(let platform): platform.rawValue
        case .custom: "custom"
        }
    }
}
