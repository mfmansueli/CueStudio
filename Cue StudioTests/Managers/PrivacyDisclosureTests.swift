//
//  PrivacyDisclosureTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the built app says about privacy matches the published policy (https://appoliumlabs.web.app/cue/privacy) and the App Store label
/// (`legal/app-store-connect.md`): the policy's link, Firebase's collection off until "Help improve Cue" turns it on, no IDFV, and the
/// privacy manifest's data types and purposes.
@Suite("Privacy disclosure")
struct PrivacyDisclosureTests {
    @MainActor @Test func thePolicyLinkIsTheOnePublished() {
        #expect(AppLinks.privacyPolicy?.absoluteString == "https://appoliumlabs.web.app/cue/privacy")
    }

    /// Off from the first launch: `TelemetryManager` turns Analytics and Crashlytics on only with the switch; the IDFV never goes.
    @Test(arguments: ["FIREBASE_ANALYTICS_COLLECTION_ENABLED", "FirebaseCrashlyticsCollectionEnabled", "GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED"])
    func firebaseCollectsNothingByItself(_ key: String) {
        #expect(Bundle.main.object(forInfoDictionaryKey: key) as? Bool == false, "\(key) isn't off in Info.plist")
    }

    /// Every type Cue (and Firebase Analytics, which ships no manifest of its own) collects, for what, never linked and never tracking.
    @Test func theManifestDeclaresWhatIsCollected() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        let entries = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        var purposes: [String: Set<String>] = [:]
        for entry in entries {
            let type = try #require(entry["NSPrivacyCollectedDataType"] as? String)
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == false, "\(type) is linked")
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, "\(type) tracks")
            let reasons = (entry["NSPrivacyCollectedDataTypePurposes"] as? [String]) ?? []
            purposes[Self.short(type), default: []].formUnion(reasons.map(Self.short))
        }
        let both: Set = ["Analytics", "AppFunctionality"]
        #expect(purposes == [
            "CrashData": both, "PerformanceData": both, "OtherDiagnosticData": both,
            "ProductInteraction": ["Analytics"], "CoarseLocation": ["Analytics"],
            "DeviceID": both, "OtherUserContent": ["AppFunctionality"], "PurchaseHistory": both,
        ])
    }

    private static func short(_ name: String) -> String {
        name.replacingOccurrences(of: "NSPrivacyCollectedDataTypePurpose", with: "").replacingOccurrences(of: "NSPrivacyCollectedDataType", with: "")
    }
}
