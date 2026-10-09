//
//  FeatureCatalog.swift
//  Cue Studio
//

import Foundation

/// The tools Cue may introduce, as data, in the order they are offered when several fit (writing, then recording, then editing, then the
/// universe). Every one exists in this build and was checked before it entered (`NOTIFICATIONS.md` §4): nothing planned (eye contact,
/// trends) is here. None is paid: the editor's tools are free, and exporting is never what a notification opens.
nonisolated enum FeatureCatalog {
    private static let both: Set<FeatureIntro.Channel> = [.notification, .inApp]

    static let all: [FeatureIntro] = [
        FeatureIntro(
            feature: .myCueVoice, campaignID: "discover.myCueVoice.v1", symbol: "sparkle",
            requirements: [.appleIntelligence, .scripts(2), .voiceNotConfigured], target: .place(.voiceSetup), channels: both,
            note: .appleIntelligence
        ),
        FeatureIntro(
            feature: .importWriting, campaignID: "discover.importWriting.v1", symbol: "doc.text",
            requirements: [.appleIntelligence, .voiceConfigured, .notImported], target: .place(.importWriting), channels: both,
            note: .appleIntelligence
        ),
        FeatureIntro(
            feature: .ideas, campaignID: "discover.ideas.v1", symbol: "lightbulb",
            requirements: [.appleIntelligence, .topics], target: .place(.ideas), channels: both, note: .appleIntelligence
        ),
        FeatureIntro(
            feature: .logbook, campaignID: "discover.logbook.v1", symbol: "book.closed",
            requirements: [.scripts(1)], target: .place(.logbook(entryID: nil)), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .voiceFollowing, campaignID: "discover.voiceFollowing.v1", symbol: "waveform",
            requirements: [.steadyPrompter], target: .readyScript, channels: both, note: .speechModel
        ),
        FeatureIntro(
            feature: .cleanUp, campaignID: "discover.cleanUp.v1", symbol: "scissors",
            requirements: [.recorded], target: .take(.cleanUp, tool: .cleanUp), channels: both, note: .speechModel
        ),
        FeatureIntro(
            feature: .autoCaptions, campaignID: "discover.autoCaptions.v1", symbol: "captions.bubble",
            requirements: [.recorded], target: .take(.withoutCaptions, tool: .autoCaptions), channels: both, note: .speechModel
        ),
        FeatureIntro(
            feature: .captionTranslation, campaignID: "discover.captionTranslation.v1", symbol: "character.bubble",
            requirements: [.recorded], target: .take(.translatableCaptions, tool: .captionTranslation), channels: both,
            note: .translationDownload
        ),
        FeatureIntro(
            feature: .studioVoice, campaignID: "discover.studioVoice.v1", symbol: "waveform.and.mic",
            requirements: [.recorded], target: .take(.any, tool: .studioVoice), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .covers, campaignID: "discover.covers.v1", symbol: "photo.artframe",
            requirements: [.recorded], target: .take(.unfinished, tool: .cover), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .layers, campaignID: "discover.layers.v1", symbol: "photo.badge.plus",
            requirements: [.finishedVideo], target: .take(.unfinished, tool: .media), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .voiceOver, campaignID: "discover.voiceOver.v1", symbol: "mic",
            requirements: [.finishedVideo], target: .take(.unfinished, tool: .voiceOver), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .backgrounds, campaignID: "discover.backgrounds.v1", symbol: "person.and.background.dotted",
            requirements: [.recorded, .backgrounds], target: .take(.any, tool: .background), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .skinSmoothing, campaignID: "discover.skinSmoothing.v1", symbol: "slider.horizontal.3",
            requirements: [.finishedVideo], target: .take(.unfinished, tool: .skinSmoothing), channels: both, note: .nothingChanges
        ),
        FeatureIntro(
            feature: .safeZones, campaignID: "discover.safeZones.v1", symbol: "rectangle.dashed",
            requirements: [.recorded], target: .socialVideo(.safeZone), channels: both, note: .nothingChanges
        ),
        // No sign of a second device: introduced only in the app, after a session at the teleprompter, never as a notification.
        FeatureIntro(
            feature: .remoteControl, campaignID: "discover.remoteControl.v1", symbol: "iphone.radiowaves.left.and.right",
            requirements: [.recorded], target: .place(.remote), channels: [.inApp], note: .secondDevice
        ),
        FeatureIntro(
            feature: .yourUniverse, campaignID: "discover.yourUniverse.v1", symbol: "sparkles",
            requirements: [.sharedVideos(3)], target: .place(.universe), channels: both, note: .nothingChanges
        ),
    ]

    static func intro(for feature: FeatureID) -> FeatureIntro? { all.first { $0.feature == feature } }
}
