//
//  FeatureAdoption.swift
//  Cue Studio
//

import Foundation

/// What counts as having **used** a tool, which is what stops its introductions: a result the creator kept, never a panel opened or a
/// notification tapped (`NOTIFICATIONS.md` §7). Read from what is saved wherever it can be (an edit with captions, a voice with answers);
/// the rest comes from events the app records when the use happens (`NotificationService.recordUse`).
nonisolated enum FeatureAdoption {
    /// The tools a take's edit shows were used.
    static func tools(in edit: TakeEdit?) -> Set<FeatureID> {
        guard let edit else { return [] }
        var used: Set<FeatureID> = []
        // Clean Up: a suggestion decided (kept or removed), not only listened to.
        if edit.cleanUpAnalyzed, edit.suggestions.contains(where: { $0.status != .pending }) { used.insert(.cleanUp) }
        if !edit.captions.isEmpty { used.insert(.autoCaptions) }
        if !edit.captionTranslations.isEmpty { used.insert(.captionTranslation) }
        if edit.voiceEnhancement != .soft || edit.noiseReduction != .off { used.insert(.studioVoice) }
        if edit.skinSmoothing > 0 || edit.timeline.segments.contains(where: { ($0.look?.skinSmoothing ?? 0) > 0 }) { used.insert(.skinSmoothing) }
        if !edit.backgrounds.isEmpty { used.insert(.backgrounds) }
        if edit.cover != nil { used.insert(.covers) }
        if !edit.media.isEmpty { used.insert(.layers) }
        if !edit.voiceOvers.isEmpty { used.insert(.voiceOver) }
        return used
    }

    /// Everything seen used: the takes' tools, the profile, the Logbook, the prompter's own settings, and the events.
    static func adopted(
        takeTools: [Set<FeatureID>], profile: NotificationFacts.Profile, hasLogbookEntries: Bool, prompterFollowsVoice: Bool,
        showsSafeZone: Bool, events: Set<FeatureID>
    ) -> Set<FeatureID> {
        var adopted = events.union(takeTools.reduce(into: Set<FeatureID>()) { $0.formUnion($1) })
        if profile.voiceConfigured { adopted.insert(.myCueVoice) }
        if profile.hasImportedWriting { adopted.insert(.importWriting) }
        if hasLogbookEntries { adopted.insert(.logbook) }
        if prompterFollowsVoice { adopted.insert(.voiceFollowing) }
        if showsSafeZone { adopted.insert(.safeZones) }
        return adopted
    }
}
