//
//  TelemetryPolicyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Analytics and crash reports come only from a creator's launches, never from tests or Xcode previews.
@Suite("TelemetryPolicy")
struct TelemetryPolicyTests {
    private let app = "/private/var/containers/Bundle/Application/Cue Studio.app/Cue Studio"

    @Test func anOrdinaryLaunchSendsReports() {
        #expect(TelemetryPolicy.sendsReports(arguments: [app], environment: ["HOME": "/var/mobile"]))
    }

    @Test func uiTestsSendNothing() {
        #expect(!TelemetryPolicy.sendsReports(arguments: [app, "-uiTestInMemory", "-uiTestSeedSamples"], environment: [:]))
    }

    @Test func theUnitTestsHostSendsNothing() {
        let environment = ["XCTestConfigurationFilePath": "/tmp/Cue StudioTests.xctestconfiguration"]
        #expect(!TelemetryPolicy.sendsReports(arguments: [app], environment: environment))
    }

    @Test func previewsSendNothing() {
        #expect(!TelemetryPolicy.sendsReports(arguments: [app], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]))
    }

    /// The launch these tests run in: Firebase never starts while the suite runs.
    @Test func thisTestRunSendsNothing() {
        let process = ProcessInfo.processInfo
        #expect(!TelemetryPolicy.sendsReports(arguments: process.arguments, environment: process.environment))
    }
}
