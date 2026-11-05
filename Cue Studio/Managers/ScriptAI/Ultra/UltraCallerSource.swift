//
//  UltraCallerSource.swift
//  Cue Studio
//

import Foundation

/// Where Ultra AI's calls learn who they are for (`UltraCaller`): the install's random id the invites keep in the Keychain
/// (`ReferralService.installIdentity`), and on Cue Pro the App Store's signed transaction (`StoreManager.proProof`). Set once both exist
/// (`AppServices`); without it the calls say nothing about the creator, as builds before metering did.
@MainActor
struct UltraCallerSource {
    let installID: @MainActor () -> UUID?
    let proof: @MainActor () async -> String?
}
