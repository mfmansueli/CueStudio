//
//  UltraConsentServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI's permission is its own: allowing or revoking it leaves Apple Intelligence's switch as it was, and it is remembered.
@MainActor
@Suite("Ultra AI permission")
struct UltraConsentServiceTests {
    @Test func grantedAndRevokedApartFromAppleIntelligence() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let privacy = PrivacyPreferencesService(defaults: defaults.defaults, writer: FakeScriptWriter())
        let appleWas = privacy.usesOnDeviceAI
        let consent = UltraConsentService(defaults: defaults.defaults, now: { TestData.now })
        #expect(!consent.isGranted)
        consent.grant()
        #expect(UltraConsentService(defaults: defaults.defaults).grantedAt == TestData.now)
        #expect(privacy.usesOnDeviceAI == appleWas)
        consent.revoke()
        #expect(!UltraConsentService(defaults: defaults.defaults).isGranted)
        #expect(privacy.usesOnDeviceAI == appleWas)
    }
}
