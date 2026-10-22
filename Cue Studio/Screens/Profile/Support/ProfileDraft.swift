//
//  ProfileDraft.swift
//  Cue Studio
//

import Foundation

/// What Edit Profile changes while the sheet is open (9.1, `09` "Cascade · v30"): the name, the username, the creator type and the photo, and what new
/// scripts start with (the platform "Create for" begins on, and the monetization goals). Nothing
/// reaches the profile until Done. The name and the username are optional (nothing in Cue needs them, and Done must still keep a photo or a
/// platform chosen without them); one that is typed must fit: a name of up to 40 characters, a username of 2–24 letters, numbers, "." or "_".
nonisolated struct ProfileDraft: Equatable, Sendable {
    static let nameLimit = 1...40
    static let handleLimit = 2...24

    var name: String
    var handle: String
    var role: CreatorRole?
    /// A creator type of their own ("Podcaster", "Chef"), in place of `role` when set: the one My Cue Voice keeps too.
    var customRole: String?
    var photoData: Data?
    /// The platform "Create for" begins on.
    var defaultPlatform: Platform
    /// Whether the length goals aim at what earns money.
    var monetizationGoals: Bool

    init(_ profile: CreatorProfile) {
        name = profile.name
        handle = profile.handle
        role = profile.role
        customRole = profile.customRole
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

    /// Empty, or 1–40 characters once trimmed.
    var isNameValid: Bool { trimmedName.isEmpty || Self.nameLimit.contains(trimmedName.count) }

    /// Empty, or 2–24 of a–z 0–9 . _
    var isHandleValid: Bool { handle.isEmpty || Self.handleLimit.contains(handle.count) && handle == Self.sanitized(handle) }

    /// Done is enabled.
    var isValid: Bool { isNameValid && isHandleValid }

    /// The footer under the name while it is too long: "Up to 40 characters".
    var nameError: String? { isNameValid ? nil : String(localized: "Up to 40 characters") }

    /// The footer under the username while it is wrong: "Use 2 to 24 letters, numbers, . or _".
    var handleError: String? { isHandleValid ? nil : String(localized: "Use 2 to 24 letters, numbers, . or _") }

    /// What the creator type reads as: their own, else the chosen one's name ("Educator"), nil when none.
    var creatorType: String? { customRole ?? role?.creatorLabel }

    /// Longest creator type of their own.
    static let customRoleLimit = 30

    /// The profile with the draft's fields.
    func applied(to profile: CreatorProfile) -> CreatorProfile {
        var profile = profile
        profile.name = trimmedName
        profile.handle = handle
        profile.role = role
        profile.customRole = customRole.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        profile.photoData = photoData
        profile.defaultPlatform = defaultPlatform
        profile.monetizationGoals = monetizationGoals
        return profile
    }
}
