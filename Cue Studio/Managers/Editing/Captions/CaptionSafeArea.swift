//
//  CaptionSafeArea.swift
//  Cue Studio
//

import Foundation

/// The existing platform rules, shared by editor initialization and export-time recognition: the captions keep to the clear area of
/// the video's safe zone guide (`SafeGuideZones`), its platform's by the script, or the one the creator picked in the editor
/// (`TakeEdit.safeGuide`). Snapshots live in CaptionSettings; opening a saved recipe never rewrites its margins.
@MainActor
enum CaptionSafeArea {
    static let zones = SafeGuideZones(rules: PlatformRulesService.bundledRules())

    /// The captions' margins for `take` on `aspect`, by the guide picked (nil: the one the script's platform suggests).
    static func margins(for take: Take, aspect: AspectRatio, pick: SafeGuideChoice? = nil) -> SafeZoneMargins {
        zones.margins(of: zones.resolve(pick: pick, scriptPlatform: take.platform, aspect: aspect), aspect: aspect)
    }

    /// The guide `edit` shows on `take` (`SafeGuideZones.active`).
    static func guide(of edit: TakeEdit, for take: Take) -> SafeGuideChoice {
        zones.active(
            pick: edit.safeGuide, scriptPlatform: take.platform, aspect: edit.aspect, captionMargins: edit.captionCollection?.safeMargins
        )
    }

    /// An edit saved before the margins followed Format (07/11/2026) kept the recording's shape's margins on another shape: those
    /// are put right for the shape it has, so the preview and the file place the lines alike. Margins the creator never sees can't
    /// have been chosen, so only the recording's own are replaced (as they are now, or as a take with no platform got them before
    /// the guide: Reels' on 9:16, LinkedIn's on 4:5); any other snapshot stays as it was saved.
    static func repairMargins(of edit: inout TakeEdit, for take: Take) {
        guard edit.aspect != take.aspect, let margins = edit.captionCollection?.safeMargins,
              margins == Self.margins(for: take, aspect: take.aspect) || margins == marginsBeforeTheGuide(for: take, aspect: take.aspect)
        else { return }
        edit.captionCollection?.safeMargins = Self.margins(for: take, aspect: edit.aspect, pick: edit.safeGuide)
    }

    /// What a take's captions got before the guide (08/11/2026): its platform's zone when measured on the frame, Reels' for a take
    /// with no platform on 9:16 and LinkedIn's on other frames, else the frame's edges.
    private static func marginsBeforeTheGuide(for take: Take, aspect: AspectRatio) -> SafeZoneMargins {
        let platform = take.platform ?? (aspect == .portrait ? .reels : .linkedin)
        guard let zone = zones.rules.safeZone(for: platform), zone.aspect == aspect else { return .frameEdges }
        return SafeGuideZones.margins(of: zone)
    }
}
