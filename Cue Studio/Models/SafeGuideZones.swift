//
//  SafeGuideZones.swift
//  Cue Studio
//

import Foundation

/// The editor's safe zone guide by the platform rules: which guides a frame offers, where each one's clear area is, and which
/// one a video shows. The captions keep to the guide's clear area (`CaptionSafeArea`), so the line the guide draws on the
/// preview is the one the file's captions keep to. Pure: the editor, the export and the tests read the same rules.
nonisolated struct SafeGuideZones: Sendable {
    /// The platforms in the order the guide offers them (Settings › Social safe zone's order first).
    static let order: [Platform] = [.tiktok, .reels, .shorts, .stories, .linkedin, .youtube]

    let rules: PlatformRules

    /// The guides for a frame, in the order the editor offers them: the platforms whose buttons were measured on it, then Generic.
    func options(for aspect: AspectRatio) -> [SafeGuideChoice] {
        measured(on: aspect).map { .platform($0) } + [.generic]
    }

    /// What a video starts with: the script's platform when its buttons were measured on this frame, else Generic.
    func suggestion(scriptPlatform: Platform?, aspect: AspectRatio) -> SafeGuideChoice {
        guard let scriptPlatform, measured(on: aspect).contains(scriptPlatform) else { return .generic }
        return .platform(scriptPlatform)
    }

    /// The guide the video shows and its captions keep to: the creator's pick while it fits the frame, else the suggestion.
    func resolve(pick: SafeGuideChoice?, scriptPlatform: Platform?, aspect: AspectRatio) -> SafeGuideChoice {
        if let pick, options(for: aspect).contains(pick) { return pick }
        return suggestion(scriptPlatform: scriptPlatform, aspect: aspect)
    }

    /// The guide an edit shows. An edit saved before the guide had no pick: its captions keep the margins of the platform they
    /// were placed for then (a take with no platform took Reels' on 9:16 and LinkedIn's on 4:5), so that platform's guide is the
    /// one that tells the truth about where its lines sit.
    func active(pick: SafeGuideChoice?, scriptPlatform: Platform?, aspect: AspectRatio, captionMargins: SafeZoneMargins?) -> SafeGuideChoice {
        let resolved = resolve(pick: pick, scriptPlatform: scriptPlatform, aspect: aspect)
        guard pick == nil, let captionMargins, captionMargins != margins(of: resolved, aspect: aspect) else { return resolved }
        return options(for: aspect).first { margins(of: $0, aspect: aspect) == captionMargins } ?? resolved
    }

    /// The guide's clear area as margins of the frame. A platform measured on another frame (TikTok on 1:1) reads as Generic.
    func margins(of choice: SafeGuideChoice, aspect: AspectRatio) -> SafeZoneMargins {
        switch choice {
        case .platform(let platform):
            guard let zone = rules.safeZone(for: platform), zone.aspect == aspect else { return generic(aspect) }
            return Self.margins(of: zone)
        case .generic:
            return generic(aspect)
        }
    }

    /// Generic: where several apps' buttons were measured on the frame (9:16), clear of all of them, edge by edge; on a frame with
    /// one app or none (4:5, 1:1, 16:9), the frame's own edges (`SafeZoneMargins.frameEdges`), as Format has always kept there.
    func generic(_ aspect: AspectRatio) -> SafeZoneMargins {
        let zones = measured(on: aspect).compactMap { rules.safeZone(for: $0) }.map(Self.margins(of:))
        guard zones.count > 1 else { return .frameEdges }
        return SafeZoneMargins(
            top: zones.map(\.top).max() ?? 0, bottom: zones.map(\.bottom).max() ?? 0,
            left: zones.map(\.left).max() ?? 0, right: zones.map(\.right).max() ?? 0
        )
    }

    /// A platform's measured zone as percentages of its frame.
    static func margins(of zone: SocialSafeZonePreset) -> SafeZoneMargins {
        SafeZoneMargins(
            top: zone.top / zone.videoHeight * 100, bottom: zone.bottom / zone.videoHeight * 100,
            left: zone.left / zone.videoWidth * 100, right: zone.right / zone.videoWidth * 100
        )
    }

    /// The platforms whose buttons were measured on `aspect`, in the order the guide offers them.
    private func measured(on aspect: AspectRatio) -> [Platform] {
        Self.order.filter { rules.safeZone(for: $0)?.aspect == aspect }
    }
}
