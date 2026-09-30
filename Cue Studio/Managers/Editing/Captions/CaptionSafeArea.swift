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
}
