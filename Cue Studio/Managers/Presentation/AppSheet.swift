//
//  AppSheet.swift
//  Cue Studio
//

import Foundation

/// Sheets presented over the tab bar.
enum AppSheet: Identifiable, Hashable {
    /// "+" on Scripts: write my own, or import.
    case newScript
    /// The Record tab: read from a recent script, start a new one, or record freestyle.
    case startRecording
    case importScript
    /// "Need an idea?" on the idea card: ideas from the creator's topics.
    case ideas
    /// "Format ⌄" on the idea card: how Cue builds the script.
    case format
    /// "Start from a format" in "+": a blank draft with a format's sections, which you write.
    case startFromFormat
    /// A sponsored ad's brand brief (what the ad may say), from the format sheet.
    case brandBrief(BrandBriefPurpose)
    /// "For TikTok ⌄" on the idea card: the platform the idea is for.
    case createFor
    /// Ideas caught now, shaped later.
    case logbook
    /// A question from the audience, turned into a script.
    case answerComment
    /// A tool introduced in the app (a discovery notification, or a quiet moment): one benefit, "Try it", "Not now".
    case featureIntro(FeatureIntroRequest)
    /// My Cue Voice's four questions, opened from a notification.
    case voiceSetup
    /// Import my writing, opened from a notification.
    case importWriting
    /// Cue's invitation to allow notifications, before the system's question.
    case notificationInvite(NotificationInviteReason)

    var id: String {
        switch self {
        case .newScript: "newScript"
        case .startRecording: "startRecording"
        case .importScript: "importScript"
        case .ideas: "ideas"
        case .format: "format"
        case .startFromFormat: "startFromFormat"
        case .brandBrief(let purpose): "brandBrief.\(purpose)"
        case .createFor: "createFor"
        case .logbook: "logbook"
        case .answerComment: "answerComment"
        case .featureIntro(let request): "featureIntro.\(request.id)"
        case .voiceSetup: "voiceSetup"
        case .importWriting: "importWriting"
        case .notificationInvite(let reason): "notificationInvite.\(reason.rawValue)"
        }
    }
}

/// What the brand brief is for: "✦ Write the ad" now (from the card's format), or the sections of a draft to write by hand.
enum BrandBriefPurpose: Hashable {
    case writeFromCard
    case draft
}
