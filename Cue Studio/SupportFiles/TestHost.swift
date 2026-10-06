//
//  TestHost.swift
//  Cue Studio
//

import Foundation

/// Whether a launch only hosts the unit tests. They run inside the app (it is their test host, under XCTest and Swift Testing
/// alike), and a studio loading the library and drawing its sky on the main actor would compete with every `@MainActor` test
/// for the whole run; the host gets an empty window instead. UI tests launch the real app, always in memory (`LaunchOptions`).
nonisolated enum TestHost {
    static func hostsUnitTests(arguments: [String], environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil && !arguments.contains("-uiTestInMemory")
    }

    /// This launch.
    static var isHostingUnitTests: Bool {
        let process = ProcessInfo.processInfo
        return hostsUnitTests(arguments: process.arguments, environment: process.environment)
    }
}
