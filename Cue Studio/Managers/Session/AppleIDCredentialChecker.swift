//
//  AppleIDCredentialChecker.swift
//  Cue Studio
//

import AuthenticationServices

@MainActor
final class AppleIDCredentialChecker: AppleIDCredentialChecking {
    func wasRevoked(userID: String) async -> Bool {
        guard let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID) else { return false }
        return state == .revoked || state == .notFound
    }
}
