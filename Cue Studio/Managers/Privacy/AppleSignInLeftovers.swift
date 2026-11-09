//
//  AppleSignInLeftovers.swift
//  Cue Studio
//

import Foundation

/// What Sign in with Apple left on this iPhone. It only filled the profile's name, so it was removed (owner, 09/11/2026); the account it kept
/// (Apple's user identifier for Cue, and the name and email Apple shared once, `DefaultsKey.legacyAppleAccount`) has no use any more and goes.
/// The name the creator sees is the profile's own (`CreatorProfile.name`, which signing in only copied into when it was empty): it stays exactly
/// as it is, still theirs to edit. Erased at every launch (after the first, there is nothing to erase) and by "Delete my Cue data".
enum AppleSignInLeftovers {
    static func erase(from defaults: UserDefaults) {
        defaults.removeObject(forKey: DefaultsKey.legacyAppleAccount)
    }
}
