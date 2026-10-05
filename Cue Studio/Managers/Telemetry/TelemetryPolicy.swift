//
//  TelemetryPolicy.swift
//  Cue Studio
//

import Foundation

/// Whether a launch sends analytics and crash reports. Tests and Xcode previews never do: their sessions and crashes
/// aren't a creator's, and every test run would show up in the Firebase console as launches nobody made.
nonisolated enum TelemetryPolicy {
    static func sendsReports(arguments: [String], environment: [String: String]) -> Bool {
        // The unit tests run inside the app (it is their test host), under XCTest and Swift Testing alike.
        if environment["XCTestConfigurationFilePath"] != nil { return false }
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return false }
        // Every UI test launches in memory (`LaunchOptions`).
        return !arguments.contains("-uiTestInMemory")
    }
}
