//
//  TestHostTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The app opens an empty window only when it hosts the unit tests: a creator's launch and the UI tests get the studio.
@Suite("TestHost")
struct TestHostTests {
    private let app = "/private/var/containers/Bundle/Application/Cue Studio.app/Cue Studio"
    private let xcTest = ["XCTestConfigurationFilePath": "/tmp/Cue StudioTests.xctestconfiguration"]

    @Test func anOrdinaryLaunchIsTheStudio() {
        #expect(!TestHost.hostsUnitTests(arguments: [app], environment: ["HOME": "/var/mobile"]))
    }

    @Test func theUnitTestsHostIsBare() {
        #expect(TestHost.hostsUnitTests(arguments: [app], environment: xcTest))
    }

    /// A UI test's app is the real one, even if XCTest's configuration ever reached it.
    @Test func aUITestLaunchIsTheStudio() {
        #expect(!TestHost.hostsUnitTests(arguments: [app, "-uiTestInMemory"], environment: [:]))
        #expect(!TestHost.hostsUnitTests(arguments: [app, "-uiTestInMemory", "-uiTestSeedSamples"], environment: xcTest))
    }

    /// The launch these tests run in.
    @Test func thisTestRunIsHostedByABareApp() {
        #expect(TestHost.isHostingUnitTests)
    }
}
