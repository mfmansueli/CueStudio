//
//  InviteCopy.swift
//  Cue Studio
//

import Foundation

/// The invites' words (DESIGN_PROJECT §60), in one place so the sheet, the Profile row and the moments after an export say the same thing.
nonisolated enum InviteCopy {
    /// The message a creator shares (the owner's words, 05/11/2026), as plain text so every app it lands in shows it as typed: what Cue does,
    /// the App Store link on its own line, the creator's code **alone on its line with a blank line before and after** (nothing beside it, so a
    /// long press selects just the code), and where to type it, with the names the app shows ("Profile", "Invite friends"). Built line by
    /// line, so no translation can put anything next to the code. In the interface language picked in Cue, or `language` (the tests').
    static func message(code: String, link: URL?, language: CueLanguage? = nil) -> String {
        [
            String(localized: "Ready to put your ideas into orbit? 🚀 I make my videos with Cue Studio: from the first idea to the script, from recording to editing. And the teleprompter follows my voice while I record.", writtenIn: language),
            "",
            String(localized: "Come create too:", writtenIn: language),
            link?.absoluteString ?? String(localized: "Find Cue Studio on the App Store.", writtenIn: language),
            "",
            String(localized: "My invite code:", writtenIn: language),
            "",
            code.trimmingCharacters(in: .whitespacesAndNewlines),
            "",
            String(localized: "Install the app and go to Profile › Invite friends › type the code above before you export your first video. ✨", writtenIn: language),
        ].joined(separator: "\n")
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
