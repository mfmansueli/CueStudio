//
//  VoiceInference.swift
//  Cue Studio
//

import Foundation

/// What Cue can tell from what the creator already did, offered to confirm instead of asked (the owner's item 6, 02/11/2026). It looks at what they
/// film most (the kinds of their last scripts), where they share and how long (their exports), and how iOS says to address them. Nothing is used
/// until they say yes: a suggestion fills an answer only when it is confirmed.
nonisolated enum VoiceInference {
    /// One thing Cue noticed, with what it is based on.
    enum Suggestion: Hashable, Identifiable, Sendable {
        /// The kinds of video most of their last `scripts` scripts are.
        case formats([ScriptType], scripts: Int)
        /// Where most of their last `exports` exports went, and how long those videos run.
        case reach(Platform, VideoLength?, exports: Int)
        /// The term of address set in iOS.
        case gender(WordGender)

        var id: String {
            switch self {
            case .formats: "formats"
            case .reach: "reach"
            case .gender: "gender"
            }
        }
    }

    /// An export that left Cue: where it went (nil when the app it went to says nothing of a platform, as a save to Photos) and how long it runs.
    struct Export: Hashable, Sendable {
        var platform: Platform?
        var seconds: TimeInterval?
    }

    /// How many recent scripts and exports are looked at, and how many must agree.
    static let recentScripts = 6
    static let recentExports = 10
    static let agreeing = 3
    static let agreeingExports = 2

    /// - Parameters:
    ///   - asksGender: whether the script language changes words with the creator's gender (`AgreementGuide.genderExample`).
    static func suggestions(
        for profile: CreatorProfile, scripts: [Script], exports: [Export], deviceGender: WordGender?, asksGender: Bool
    ) -> [Suggestion] {
        var found: [Suggestion] = []
        if let formats = formats(for: profile, scripts: scripts) { found.append(formats) }
        if let reach = reach(for: profile, exports: exports) { found.append(reach) }
        if asksGender, profile.resolvedSpeaksAs != .we, profile.agreement.speaker == nil, let deviceGender { found.append(.gender(deviceGender)) }
        return found
    }

    private static func formats(for profile: CreatorProfile, scripts: [Script]) -> Suggestion? {
        guard profile.formats.isEmpty, profile.customFormats.isEmpty, profile.formatTags.isEmpty, !profile.declinedVoiceItems.contains(.formats) else {
            return nil
        }
        let recent = scripts.filter { $0.type != nil }.sorted { $0.createdAt > $1.createdAt }.prefix(recentScripts)
        let counts = Dictionary(grouping: recent.compactMap(\.type), by: { $0 }).mapValues(\.count)
        let kinds = counts.filter { $0.value >= agreeing }.sorted { ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }.map(\.key)
        guard !kinds.isEmpty else { return nil }
        return .formats(Array(kinds.prefix(VoiceLimits.formats)), scripts: recent.count)
    }

    private static func reach(for profile: CreatorProfile, exports: [Export]) -> Suggestion? {
        guard profile.reach.platforms.isEmpty else { return nil }
        let recent = exports.suffix(recentExports)
        let counts = Dictionary(grouping: recent.compactMap(\.platform), by: { $0 }).mapValues(\.count)
        guard let top = counts.max(by: { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }), top.value >= agreeingExports else { return nil }
        let seconds = recent.filter { $0.platform == top.key }.compactMap(\.seconds).sorted()
        let length = profile.reach.length == nil && !seconds.isEmpty ? VideoLength(containing: seconds[seconds.count / 2]) : nil
        return .reach(top.key, length, exports: recent.count)
    }

    /// Where an export went, as far as the evidence says.
    static func platform(of evidence: DeliveryEvidence) -> Platform? {
        switch evidence {
        case .tikTokShareKit: return .tiktok
        case .pasteboardHandoff: return .reels
        case .photoLibrary: return nil
        case .activity(let type):
            let type = type?.lowercased() ?? ""
            if type.contains("musically") || type.contains("tiktok") { return .tiktok }
            if type.contains("instagram") { return .reels }
            if type.contains("youtube") { return .shorts }
            if type.contains("linkedin") { return .linkedin }
            return nil
        }
    }
}
