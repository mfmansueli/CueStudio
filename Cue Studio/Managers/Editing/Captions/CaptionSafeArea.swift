//
//  CaptionSafeArea.swift
//  Cue Studio
//

import Foundation

/// The existing platform rules, shared by editor initialization and export-time recognition.
/// Snapshots live in CaptionSettings; opening a saved recipe never rewrites its margins.
@MainActor
enum CaptionSafeArea {
    private static let rules = PlatformRulesService.bundledRules()

    static func margins(for take: Take, aspect: AspectRatio) -> SafeZoneMargins {
        let platform = take.platform ?? (aspect == .portrait ? .reels : .linkedin)
        guard let zone = rules.safeZone(for: platform), zone.aspect == aspect else {
            return SafeZoneMargins(top: 5, bottom: 7, left: 6, right: 6)
        }
        return SafeZoneMargins(top: zone.top / zone.videoHeight * 100, bottom: zone.bottom / zone.videoHeight * 100,
                               left: zone.left / zone.videoWidth * 100, right: zone.right / zone.videoWidth * 100)
    }

    /// An edit saved before the margins followed Format (07/11/2026) kept the recording's shape's margins on another shape: those
    /// are put right for the shape it has, so the preview and the file place the lines alike. Margins the creator never sees can't
    /// have been chosen, so only the recording's own are replaced; any other snapshot stays as it was saved.
    static func repairMargins(of edit: inout TakeEdit, for take: Take) {
        guard edit.aspect != take.aspect, let margins = edit.captionCollection?.safeMargins,
              margins == Self.margins(for: take, aspect: take.aspect) else { return }
        edit.captionCollection?.safeMargins = Self.margins(for: take, aspect: edit.aspect)
    }
}
