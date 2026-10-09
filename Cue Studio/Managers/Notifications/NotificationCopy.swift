//
//  NotificationCopy.swift
//  Cue Studio
//

import Foundation

/// What every notification says (`NOTIFICATIONS.md` §2 lists the keys). Benefit first, one action, a light touch of Cue's sky; never guilt,
/// "we miss you", urgency that isn't real, a word about how someone looks, or a promise of views. A project's title appears only when
/// the creator turned on "Show titles in previews"; script text, comments and imported writing never do.
nonisolated enum NotificationCopy {
    // MARK: - Automatic

    static func content(for subject: NotificationSubject, showsTitles: Bool) -> NotificationContent {
        switch subject {
        case .project(let campaign, let title, let network):
            return project(campaign, title: showsTitles ? quoted(title) : nil, network: network)
        case .entryPoint:
            return NotificationContent(
                title: String(localized: "Ready for your next video?"),
                body: String(localized: "Start from an idea, a format or a blank page. Your universe has room for one more star.")
            )
        case .idea(let topic):
            if showsTitles, let topic {
                return NotificationContent(
                    title: String(localized: "An idea for your next video"),
                    body: String(localized: "Explore an idea for your next video about \(topic).")
                )
            }
            return NotificationContent(
                title: String(localized: "An idea for your next video"),
                body: String(localized: "Cue has an idea ready for your topics. Explore it when you’re ready.")
            )
        case .feature(let feature):
            return NotificationContent(title: FeatureCopy.notificationTitle(feature), body: FeatureCopy.notificationBody(feature))
        case .yearReview:
            return NotificationContent(
                title: String(localized: "Your year in review is ready"),
                body: String(localized: "See the videos that shaped your universe this year.")
            )
        case .whatsNew:
            return NotificationContent(
                title: String(localized: "New in Cue"),
                body: String(localized: "A new tool arrived with this version. Open Cue to see it.")
            )
        }
    }

    private static func project(_ campaign: NotificationCampaign, title: String?, network: ShareDestination?) -> NotificationContent {
        switch campaign {
        case .firstRecording:
            NotificationContent(
                title: String(localized: "Your first script is ready"),
                body: String(localized: "Try recording it with the teleprompter. Your first star is one take away.")
            )
        case .unfinishedScript:
            NotificationContent(
                title: title.map { String(localized: "\($0) has already started") } ?? String(localized: "Your idea has already started"),
                body: String(localized: "Continue where you left off.")
            )
        case .readyToRecord:
            NotificationContent(
                title: String(localized: "Turn your script into a video"),
                body: title.map { String(localized: "\($0) is ready. Your next recording is one tap away.") }
                    ?? String(localized: "Your next recording is one tap away.")
            )
        case .recordingToFinish:
            NotificationContent(
                title: String(localized: "Your recording is saved"),
                body: String(localized: "Continue editing whenever you’re ready.")
            )
        case .incompleteSharing:
            NotificationContent(
                title: network.map { String(localized: "Next stop: \($0.platform.label)") } ?? String(localized: "Continue sharing your video"),
                body: String(localized: "Continue sharing your video on the networks you selected.")
            )
        case .savedIdea:
            NotificationContent(
                title: String(localized: "An idea is waiting in your Logbook"),
                body: String(localized: "One of your ideas is waiting to become a video. Want to develop it?")
            )
        default:
            content(for: .entryPoint, showsTitles: false)
        }
    }

    // MARK: - Set by the creator

    static func reminder(_ subject: ReminderSubject, title: String, showsTitles: Bool) -> NotificationContent {
        let named = showsTitles && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? quoted(title) : nil
        switch subject {
        case .script:
            return NotificationContent(
                title: named.map { String(localized: "\($0) is waiting") } ?? String(localized: "Your script is waiting"),
                body: String(localized: "Open it to keep going. Record it when you’re ready.")
            )
        case .take:
            return NotificationContent(
                title: named.map { String(localized: "\($0) is waiting") } ?? String(localized: "Your recording is waiting"),
                body: String(localized: "Pick up the edit, or share it when you’re ready.")
            )
        case .share(_, let network):
            return NotificationContent(
                title: String(localized: "Ready to post on \(network.platform.label)"),
                body: named.map { String(localized: "\($0) is saved in Cue. Open it to continue sharing.") }
                    ?? String(localized: "Your video is saved in Cue. Open it to continue sharing.")
            )
        }
    }

    static var routine: NotificationContent {
        NotificationContent(
            title: String(localized: "Your creation time"),
            body: String(localized: "Your next video starts here. Cue opens on the step that’s next.")
        )
    }

    static func exportReady(savedToPhotos: Bool) -> NotificationContent {
        NotificationContent(
            title: String(localized: "Your video is ready"),
            body: savedToPhotos
                ? String(localized: "It’s saved to Photos. Open Cue to share it.")
                : String(localized: "Open Cue to share it.")
        )
    }

    /// “3 morning habits”, in the interface's quotation marks.
    private static func quoted(_ title: String) -> String {
        let locale = InterfaceLocale.current ?? .current
        let open = locale.quotationBeginDelimiter ?? "“"
        let close = locale.quotationEndDelimiter ?? "”"
        return open + title.trimmingCharacters(in: .whitespacesAndNewlines) + close
    }
}
