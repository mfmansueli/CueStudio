//
//  ScriptAIServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// FoundationModels stops the app on the first Private Cloud Compute request when the entitlement
/// is missing, so the service must never offer it without one.
@Suite("ScriptAIService")
@MainActor
struct ScriptAIServiceTests {
    @Test func privateCloudComputeIsNeverOfferedWhenOff() {
        #expect(ScriptAIService(usesPrivateCloudCompute: false).availability.privateCloud == false)
    }

    @Test func privateCloudComputeIsOnOnlyWithTheEntitlement() throws {
        let entitlements = URL(filePath: #filePath)
            .deletingLastPathComponent() // Managers
            .deletingLastPathComponent() // Cue StudioTests
            .deletingLastPathComponent() // project
            .appending(path: "Cue Studio/SupportFiles/Cue Studio.entitlements")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: entitlements), format: nil)
        let values = try #require(plist as? [String: Any])
        let entitled = values["com.apple.developer.private-cloud-compute"] as? Bool ?? false
        #expect(ScriptAIService.hasPrivateCloudComputeEntitlement == entitled)
    }
}
