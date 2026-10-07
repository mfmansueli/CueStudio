//
//  ProfileDraft.swift
//  Cue Studio
//

import Foundation

/// What Edit Profile changes while the sheet is open (9.1, `09` "Cascade · v30"): the name, the username, the creator type and the photo, and what new
/// scripts start with (the platform "Create for" begins on, and the monetization goals). Nothing
/// reaches the profile until Done, and Done waits for a valid draft: a name of 1–40 characters and a username of 2–24 letters, numbers, "." or "_".
nonisolated struct ProfileDraft: Equatable, Sendable {
    static let nameLimit = 1...40
    static let handleLimit = 2...24

    var name: String
    var handle: String
    var role: CreatorRole?
    var photoData: Data?
    /// The platform "Create for" begins on.
    var defaultPlatform: Platform
    /// Whether the length goals aim at what earns money.
    var monetizationGoals: Bool

    init(_ profile: CreatorProfile) {
        name = profile.name
        handle = profile.handle
        role = profile.role
        photoData = profile.photoData
        defaultPlatform = profile.defaultPlatform
        monetizationGoals = profile.monetizationGoals
    }

    /// What a typed username becomes: lowercase, no spaces, nothing but a–z, 0–9, "." and "_".
    static func sanitized(_ handle: String) -> String {
        String(handle.lowercased().unicodeScalars.filter { allowed.contains($0) }.map(Character.init))
    }

    private static let allowed: Set<Unicode.Scalar> = Set("abcdefghijklmnopqrstuvwxyz0123456789._".unicodeScalars)

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isNameValid: Bool { Self.nameLimit.contains(trimmedName.count) }

    var isHandleValid: Bool { Self.handleLimit.contains(handle.count) && handle == Self.sanitized(handle) }

    /// Done is enabled.
    var isValid: Bool { isNameValid && isHandleValid }

    /// The footer under the username while it is wrong: "Use 2–24 letters, numbers, . or _".
    var handleError: String? { isHandleValid || handle.isEmpty ? nil : String(localized: "Use 2–24 letters, numbers, . or _") }

    /// The profile with the draft's fields.
    func applied(to profile: CreatorProfile) -> CreatorProfile {
        var profile = profile
        profile.name = trimmedName
        profile.handle = handle
        profile.role = role
        profile.photoData = photoData
        profile.defaultPlatform = defaultPlatform
        profile.monetizationGoals = monetizationGoals
        return profile
    }
}
