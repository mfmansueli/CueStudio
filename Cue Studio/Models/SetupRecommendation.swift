//
//  SetupRecommendation.swift
//  Cue Studio
//

import Foundation

/// What Cue recommends for this content ("This is what we recommend for this content"). Contextual:
/// it comes from the platform the script is created for and is offered to the creator, never
/// written into the Creator Setup.
///
/// Built from `PlatformRules` today (frame, resolution, frame rate; the safe zone follows the
/// script's platform on its own). The values are a `SetupValues`, so a platform can recommend any
/// other field of the setup (text size, camera…) without a new code path.
nonisolated struct SetupRecommendation: Hashable, Sendable {
    let platform: Platform
    var values: SetupValues
    /// The platform's safe zone is drawn over the frame.
    var hasSafeZone: Bool

    init(platform: Platform, values: SetupValues, hasSafeZone: Bool = false) {
        self.platform = platform
        self.values = values
        self.hasSafeZone = hasSafeZone
    }

    init(platform: Platform, preset: PlatformPreset) {
        self.init(
            platform: platform,
            values: SetupValues(resolution: preset.resolution, frameRate: preset.frameRate, aspect: preset.aspect),
            hasSafeZone: preset.showsSafeZones
        )
    }

    /// The fields the recommendation sets; the rest stay the creator's.
    var fields: Set<SetupField> { values.fields }

    func applied(to setup: CreatorSetup) -> CreatorSetup {
        values.applied(to: setup)
    }

    /// What "Use Recommended" would change against `onScreen`, in reading order; `manual` are the fields the creator set for this take.
    /// Empty when what is on screen already matches, so there is nothing to ask.
    func changes(from onScreen: CreatorSetup, manual: Set<SetupField> = []) -> [SetupChange] {
        let recommended = applied(to: onScreen)
        let differing = values.differences(from: onScreen)
        return SetupField.allCases.filter(differing.contains).map { field in
            SetupChange(
                item: .field(field), current: onScreen.label(for: field), recommended: recommended.label(for: field),
                isManual: manual.contains(field)
            )
        }
    }

    /// "Recommended for TikTok"
    var title: String {
        String(localized: "Recommended for \(platform.destinationName)")
    }

    /// "9:16 · 1080p · 30 fps · TikTok safe zone"
    var summary: String {
        let values = applied(to: CreatorSetup()).summary(of: fields)
        guard hasSafeZone else { return values }
        return values + " · " + String(localized: "\(platform.label) safe zone")
    }

    /// "TikTok setup", on the recording screen while it's in use.
    var setupName: String {
        String(localized: "\(platform.label) setup")
    }
}
