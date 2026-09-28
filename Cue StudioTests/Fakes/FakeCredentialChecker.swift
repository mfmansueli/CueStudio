//
//  FakeCredentialChecker.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeCredentialChecker: AppleIDCredentialChecking {
    var revoked = false

    func wasRevoked(userID: String) async -> Bool { revoked }
}
