//
//  InviteCopy.swift
//  Cue Studio
//

import Foundation

/// The invites' words (DESIGN_PROJECT §60), in one place so the sheet, the Profile row and the moments after an export say the same thing.
nonisolated enum InviteCopy {
    /// The message a creator shares, in three short paragraphs so it reads as a note from a friend and survives apps that show it as typed: what
    /// Cue does, where to get it, and how to use the code (where to type it and before what), the code last so it is easy to copy.
    static func message(code: String, link: URL?) -> String {
        if let link {
            return String(localized: "I’ve been making my videos with Cue Studio 🎬 It writes the script with you, and its teleprompter follows your voice while you record.\n\nGet it here: \(link.absoluteString)\n\nBefore you export your first video, open Profile › Invite friends in Cue and type my code: \(code)")
        }
        return String(localized: "I’ve been making my videos with Cue Studio 🎬 It writes the script with you, and its teleprompter follows your voice while you record.\n\nFind Cue Studio on the App Store.\n\nBefore you export your first video, open Profile › Invite friends in Cue and type my code: \(code)")
    }

    /// The share sheet's title over the message, and the subject of an email.
    static var shareTitle: String { String(localized: "An invite to Cue Studio") }

    /// The sheet's large line: what one friend brings ("+3 exports"); once every friend counted, what they all brought ("+15 exports").
    static func headline(_ reward: ReferralReward, rewards: ReferralRewards, isComplete: Bool) -> String {
        switch (reward, isComplete) {
        case (.exports, false): String(localized: "+\(reward.perFriend) exports")
        case (.ultraScripts, false): String(localized: "+\(reward.perFriend) Ultra AI scripts")
        case (.exports, true): String(localized: "+\(rewards.bonusExports) exports")
        case (.ultraScripts, true): String(localized: "+\(rewards.bonusUltraScripts) Ultra AI scripts")
        }
    }

    /// The last of the sheet's three steps, where the reward lands.
    static func rewardStep(_ reward: ReferralReward) -> String {
        switch reward {
        case .exports: String(localized: "They export their first video: you get +\(reward.perFriend) exports")
        case .ultraScripts: String(localized: "They export their first video: you get +\(reward.perFriend) Ultra AI scripts")
        }
    }

    /// What the friends earned so far: "2 of 5 friends · +6 exports" (with what each friend was credited as: a creator who moved to Pro
    /// keeps the exports earned before, "· +6 exports · +5 Ultra AI scripts").
    static func progress(rewarded: Int, limit: Int, rewards: ReferralRewards) -> String {
        var parts = [String(localized: "\(rewarded) of \(limit) friends")]
        if rewards.bonusExports > 0 { parts.append(String(localized: "+\(rewards.bonusExports) exports")) }
        if rewards.bonusUltraScripts > 0 { parts.append(String(localized: "+\(rewards.bonusUltraScripts) Ultra AI scripts")) }
        return parts.joined(separator: " · ")
    }

    /// One line for the moments after an export and the Profile row before any friend: "+3 exports for each friend".
    static func perFriend(_ reward: ReferralReward) -> String {
        switch reward {
        case .exports: String(localized: "+\(reward.perFriend) exports for each friend")
        case .ultraScripts: String(localized: "+\(reward.perFriend) Ultra AI scripts for each friend")
        }
    }

    /// The answer to a typed code, under the field. Nil for the one that counted (the section says it instead).
    static func joinAnswer(_ outcome: ReferralJoinOutcome) -> String? {
        switch outcome {
        case .joined: nil
        case .unknown: String(localized: "No one has this code. Check it with your friend.")
        case .own: String(localized: "That’s your own code. Share it with a friend.")
        case .already: String(localized: "This iPhone already used a friend’s code.")
        case .offline: String(localized: "Couldn’t reach Cue. Check your connection and try again.")
        }
    }
}
